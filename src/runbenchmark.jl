# Package benchmarking API

shastring(r::LibGit2.GitRepo, refname) = string(LibGit2.revparseid(r, refname))
shastring(dir::AbstractString, refname) = LibGit2.with(r -> shastring(r, refname), LibGit2.GitRepo(dir))

defaultscript(pkg)     = Pkg.dir(pkg, "benchmark", "benchmarks.jl")
defaultrequire(pkg)    = Pkg.dir(pkg, "benchmark", "REQUIRE")
defaultresultsdir(pkg) = Pkg.dir(".benchmarks", pkg, "results")
defaulttunefile(pkg)   = Pkg.dir(".benchmarks", pkg, ".tune.jld")

Base.@deprecate benchmark(args...; kwargs...) benchmark(args...; kwargs...)

"""
    benchmark(pkg::String,
              config::BenchmarkConfig;
              kwargs...) -> `results`::BenchmarkResult

Runs a benchmark on the package `pkg` using the [`BenchmarkConfig`](@ref) `config`
and returns `results` which is an instance of a [`BenchmarkResult`](@ref).

**Keyword arguments**:

* `saveresults` - Provided the repository is not dirty, save results to `\$pkg/benchmark/.results`, (default `true`).
   The filename used will be a hash based on the package commit and the `config`.
   The result can be saved manually using `writeresults(file, results)` and read back with `readresults(file)`.
* `retune` - Force a [re-tuning](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#caching-parameters) of the benchmarks, (default `false`).
* `overwrite` - Overwrite the result file if it already exists, (default `true`).

**Examples**

```julia
using PkgBenchmark

benchmark("MyPkg") # run the benchmarks at the current state of the repository
benchmark("MyPkg", BenchmarkConfig(id = "my-feature")) # run the benchmarks for a particular branch/commit/tag
```

# Advanced API

There are a few more keywords available for advanced usage:

* `script` is the script with the benchmarks. Defaults to `\$pkg/benchmark/benchmarks.jl`
* `require` is the REQUIRE file containing dependencies needed for the benchmark. Defaults to `\$pkg/benchmark/REQUIRE`.
* `resultsdir` the directory where to save results. Defaults to `\$pkg/benchmark/.results`.
* `tunefile` file to use for tuning benchmarks, will be created if doesn't exist. Defaults to `\$pkg/benchmark/.tune.jld`
"""
function benchmark(pkg, ref=BenchmarkConfig();
                      script=defaultscript(pkg),
                      require=defaultrequire(pkg),
                      resultsdir=defaultresultsdir(pkg),
                      tunefile=defaulttunefile(pkg),
                      retune=false,
                      saveresults=true,
                      overwrite=true,
                      custom_loadpath="", #= used in tests =#
                      promptsave=nothing  #= deprecated =#)

    promptsave != nothing && Base.warn_once("the `promptsave` keyword is deprecated and will be removed.")
    dirty = LibGit2.with(LibGit2.isdirty, LibGit2.GitRepo(Pkg.dir(pkg)))
    ref = BenchmarkConfig(ref)
    function do_benchmark()
        sha = shastring(Pkg.dir(pkg), "HEAD")
        ref._commit = dirty ? "dirty" : sha
        ref._pkgname = pkg
        !isfile(script) && error("Benchmark script $script not found.")
        ref = BenchmarkConfig(ref)
        local_runner_save_path = tempname()
        res = with_reqs(require, () -> benchinfo("Resolving dependencies for benchmark.")) do
            benchinfo("Running benchmarks.")
            runbenchmark(script, local_runner_save_path, local_runner_save_path, tunefile, ref; retune=retune, custom_loadpath = custom_loadpath)
        end

        if !dirty
            if saveresults
                !isdir(resultsdir) && mkpath(resultsdir)
                resfile = joinpath(resultsdir, string(_hash(ref, sha), ".jld"))
                if !isfile(resfile) || overwrite == true
                    mv(local_runner_save_path, resfile; remove_destination = true)
                    benchinfo("Results of the benchmark were written to $resfile.")
                else
                    benchinfo("Found existing results, no output written.")
                end
            end
        else
            benchwarn("$(Pkg.dir(pkg)) is dirty, not attempting to file results.")
        end
        return res
    end

    if ref.id !== nothing
        if dirty
            error("repository at $(Pkg.dir(pkg)) is dirty. Please commit/stash your " *
                  "changes before benchmarking a specific commit")
        end
        return with_commit(do_benchmark, LibGit2.GitRepo(Pkg.dir(pkg)), ref.id)
    else
        # benchmark on the current state of the repo
        do_benchmark()
    end

end

function runbenchmark(benchmarkfile::String, save_path::String, output::String, tunefile::String,
                      benchmarkconfig::BenchmarkConfig; retune::Bool=false, custom_loadpath::String="")
    tmp = tempname()
    save(File(format"JLD", tmp), "config", benchmarkconfig)

    _benchmarkfile, _output, _tunefile, _custom_loadpath, _tmp, _save_path = map(escape_string, (benchmarkfile, output, tunefile, custom_loadpath, tmp, save_path))
    codecov_option = Base.JLOptions().code_coverage
    coverage = if codecov_option == 0
        "none"
    elseif codecov_option == 1
        "user"
    else
        "all"
    end
    color = Base.have_color ? "--color=yes" : "--color=no"
    compilecache = "--compilecache=" * (Bool(Base.JLOptions().use_compilecache) ? "yes" : "no")

    exec_str = isempty(_custom_loadpath) ? "" : "push!(LOAD_PATH, \"$(_custom_loadpath)\")\n"
    exec_str *=
        """
        using PkgBenchmark
        PkgBenchmark.runbenchmark_local("$_benchmarkfile", "$_output", "$_tunefile", "$_tmp", "$_save_path", $retune)
        """

    target_env = [k => v for (k, v) in benchmarkconfig.env]
    withenv(target_env...) do
        run(`$(benchmarkconfig.juliacmd) --code-coverage=$coverage $color $compilecache -e $exec_str`)
    end
    JLD.jldopen(output, "r") do f
        read(f, "results")
    end
end

function runbenchmark_local(benchmarkfile, output, tunefile, configfile, save_path, retune)
    # Define benchmarks
    _reset_stack()
    _reset_suite()
    include(benchmarkfile)
    suite = if _get_suite() != nothing # Check if using Dict based API
        _get_suite()
    else
        _root_group()
    end

    # Tuning
    if isfile(tunefile) && !retune
        benchinfo("Using benchmark tuning data in $tunefile")
        loadparams!(suite, JLD.load(tunefile, "suite"), :evals, :samples)
    else
        println("Creating benchmark tuning file $tunefile")
        mkpath(dirname(tunefile))
        tune!(suite)
        JLD.save(tunefile, "suite", params(suite))
    end

    # Running
    results = run(suite)

    # Write results
    benchmark_config = load(File(format"JLD", configfile))["config"]
    vinfo = first(split(readstring(`julia -e 'versioninfo(true)'`), "Environment"))
    results = BenchmarkResult(benchmark_config, results, now(), vinfo)
    writeresults(save_path, results)
    return nothing
end

function writeresults(file, results)
    save(File(format"JLD", file), "results", results)
end
