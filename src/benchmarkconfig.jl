"""
    BenchmarkConfig

A `BenchmarkConfig` contains the configuration for the benchmark task.
This includes the following:

* The commit of the package the benchmarks are run on.
* What julia command should be run, i.e. the path to the Julia executable and
  the command flags used (e.g. optimization level with `-O`).
* Custom environment variables (e.g. `JULIA_NUM_THREADS`).
"""
mutable struct BenchmarkConfig
    id::Union{String,Void}
    juliacmd::Cmd
    env::Dict{String,Any}
    _commit::String # This field gets set in `benchmark`
    _pkgname::String # This field gets set in `benchmark`
end

_hash(bc::BenchmarkConfig, commit) = hash(commit, hash(bc.juliacmd, hash(bc.env)))
function _filename(pkg::String, config=BenchmarkConfig())
    sha = shastring(Pkg.dir(pkg), config.id == nothing ? "HEAD" : config.id)
    return joinpath(defaultresultsdir(pkg), string(_hash(config, sha), ".jld"))
end

"""
    readresults(pkg::String, config)

"""
function readresults(pkg, config)
    if !isfile(resfile)
        error("did not find a result file for package $pkg with the given `config`")
    end
    return load(File(format"JLD", resfile))["results"]
end


"""
    BenchmarkConfig(;id::Union{String, Void} = nothing,
                     juliacmd::Cmd = `joinpath(JULIA_HOME, Base.julia_exename())`,
                     env::Dict{String, Any} = Dict{String, Any}())

Creates a `BenchmarkConfig` from the following keyword arguments:
* `id` - a git identifier like a commit, branch, tag, "HEAD", "HEAD~1" etc.
         If `id == nothing` then benchmark will be done on the current state
         of the repo (even if it is dirty).
* `juliacmd` - used to exectue the benchmarks, defaults to the julia executable
               that the Pkgbenchmark-functions are called from. Can also include command flags.
* `env` - contains custom environment variables that will be active when the
          benchmarks are run.

# Examples
```julia
BenchmarkConfig(id = "performance_improvements",
                juliacmd = `julia -O3`,
                env = Dict("JULIA_NUM_THREADS" => 4))
```
"""
function BenchmarkConfig(;id::Union{String,Void} = nothing,

                 juliacmd::Cmd = `$(joinpath(JULIA_HOME, Base.julia_exename()))`,
                 env::Dict = Dict{String,Any}())
    BenchmarkConfig(id, juliacmd, env, "", "")
end

# TODO: Head is not enough, we need the resolved hash
BenchmarkConfig(cfg::BenchmarkConfig) = cfg
BenchmarkConfig(str::String) = BenchmarkConfig(id = str)




const INDENT = "    "

function Base.show(io::IO, bcfg::BenchmarkConfig)
    println(io, "BenchmarkConfig:")
    println(io, INDENT, "id: ", bcfg.id)
    println(io, INDENT, "juliacmd: ", bcfg.juliacmd)
    print(io, INDENT, "env: ")
    if !isempty(bcfg.env)
        first = true
        for (k, v) in bcfg.env
            if !first
                println()
                print(io, INDENT, " "^strwidth("env: "))
            end
            first = false
            print(k, " => ", v)
        end
    end
end


