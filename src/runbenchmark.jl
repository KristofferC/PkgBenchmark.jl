# Package benchmarking API

shastring(r::LibGit2.GitRepo, refname) = string(LibGit2.revparseid(r, refname))
shastring(dir::AbstractString, refname) = LibGit2.with(r -> shastring(r, refname), LibGit2.GitRepo(dir))

defaultscript(pkg) =
    Pkg.dir(pkg, "benchmark", "benchmarks.jl")
defaultresultsdir(pkg) =
    Pkg.dir(".benchmarks", pkg, "results")
defaultrequire(pkg) =
    Pkg.dir(pkg, "benchmark", "REQUIRE")
defaulttunefile(pkg) =
    Pkg.dir(".benchmarks", pkg, ".tune.jld")

"""
    benchmarkpkg(pkg, [ref];
                script=defaultscript(pkg),
                require=defaultrequire(pkg),
                resultsdir=defaultresultsdir(pkg),
                saveresults=true,
                tunefile=defaulttunefile(pkg),
                retune=false,
                overwrite=true)

**Arguments**:

* `pkg` is the package to benchmark
* `ref` is the commit/branch to checkout for benchmarking. If left out, the package will be benchmarked in its current state.

**Keyword arguments**:

* `script` is the script with the benchmarks. Defaults to `PKG/benchmark/benchmarks.jl`
* `require` is the REQUIRE file containing dependencies needed for the benchmark. Defaults to `PKG/benchmark/REQUIRE`.
* `resultsdir` the directory where to file away results. Defaults to `PKG/benchmark/.results`.
   Provided the repository is not dirty, results generated will be saved in this directory in a file named `<SHA1_of_commit>.jld`.
   And can be used later by functions such as `judge`. If you choose to, you can save the results manually using
   `writeresults(file, results)` where `results` is the return value of `benchmarkpkg` function.
   It can be read back with `readresults(file)`.
* `saveresults` if set to false, results will not be saved in `resultsdir`.
* `tunefile` file to use for tuning benchmarks, will be created if doesn't exist. Defaults to `PKG/benchmark/.tune.jld`
* `retune` force a re-tune, saving results to the tune file
* `overwrite` overwrites the result file if it already exists

**Returns:**

A `BenchmarkGroup` object with the results of the benchmark.

**Example invocations:**

```julia
using PkgBenchmark

benchmarkpkg("MyPkg") # run the benchmarks at the current state of the repository
benchmarkpkg("MyPkg", "my-feature") # run the benchmarks for a particular branch/commit/tag
benchmarkpkg("MyPkg", "my-feature"; script="/home/me/mycustombenchmark.jl", resultsdir="/home/me/benchmarkXresults")
  # note: its a good idea to set a new resultsdir with a new benchmark script. `PKG/benchmark/.results` is meant for `PKG/benchmark/benchmarks.jl` script.
```
"""
function benchmarkpkg(pkg, ref=BenchmarkConfig();
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

    function do_benchmark()
        !isfile(script) && error("Benchmark script $script not found")
        ref = BenchmarkConfig(ref)
        local_runner_save_path = tempname()
        res = with_reqs(require, () -> info("Resolving dependencies for benchmark")) do
            info("Running benchmarks...")
            runbenchmark(script, local_runner_save_path, local_runner_save_path, tunefile, ref; retune=retune, custom_loadpath = custom_loadpath)
        end

        if !dirty
            if saveresults
                sha = shastring(Pkg.dir(pkg), "HEAD")
                tosave = true
                if promptsave == true
                    print("File results of this run? (commit=$(sha[1:6]), resultsdir=$resultsdir) (Y/n) ")
                    response = string(readline())
                    tosave = if response == "" || lowercase(response) == "y"
                        true
                    else
                        false
                    end
                end
                if tosave
                    !isdir(resultsdir) && mkpath(resultsdir)
                    resfile = joinpath(resultsdir, string(_hash(ref, sha), ".jld"))
                    if !isfile(resfile) || overwrite == true
                        println("Writing 1...")
                        # move the result
                        mv(local_runner_save_path, joinpath(resultsdir, resfile); remove_destination = true)
                        info("Results of the benchmark were written to $resfile")
                    else
                        info("Found existing results, no output written")
                    end
                end
            end
        else
            warn("$(Pkg.dir(pkg)) is dirty, not attempting to file results...")
        end

        res
    end

    if ref.id !== nothing
        if dirty
            error("$(Pkg.dir(pkg)) is dirty. Please commit/stash your " *
                  "changes before benchmarking a specific commit")
        end
        return withcommit(do_benchmark, LibGit2.GitRepo(Pkg.dir(pkg)), ref.id)
    else
        # benchmark on the current state of the repo
        do_benchmark()
    end

end

function runbenchmark(benchmarkfile::String, save_path::String, output::String, tunefile::String, 
                      benchmarkconfig::BenchmarkConfig; retune::Bool=false, custom_loadpath::String="")    
    tmp = tempname()
    println("Saving to $tmp")
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
    readresults(output)
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
        println("Using benchmark tuning data in $tunefile")
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
    println("Writing 2...")
    vinfo = first(split(readstring(`julia -e 'versioninfo(true)'`), "Environment"))
    results = BenchmarkResult(benchmark_config, results, now(), vinfo)
    save(File(format"JLD", save_path), "results", results)
    println("Wrote it..")
    return nothing
end

function readresults(file)
    JLD.jldopen(file, "r") do f
        read(f, "results")
    end
end
