"""
    BenchmarkResult

Stores the result from running the benchmarks on a package.

The following methods are defined on a `BenchmarkResult` (written below as `result`):

* `date(result)::DateTime` - the time when the benchmarks were executed
* `versioninfo(result)::String` - the versioninfo of the julia instance that ran the benchmarks
* `benchmarkconfig(result)::BenchmarkConfig` - the [`benchmarkconfig`](@ref) of the 
* `benchmarkgroup(result)::BenchmarkGroup - a [`BenchmarkGroup`](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#the-benchmarkgroup-type)
  contaning the 
"""
struct BenchmarkResult
    benchmarkconfig::BenchmarkConfig
    benchmarkgroup::BenchmarkGroup
    date::DateTime
    vinfo::String
end

date(results::BenchmarkResult) = results.date
Base.versioninfo(results::BenchmarkResult) = results.vinfo
benchmarkconfig(results::BenchmarkResult) = results.benchmarkconfig
benchmarkgroup(results::BenchmarkResult) = results.benchmarkgroup

function Base.show(io::IO, results::BenchmarkResult)
    println(io, "Benchmarkresults")
    println(io, "    Date: ", results.date)
    println(io, "    Commit: ")
    println(io, "    Versioninfo: ")
    for l in split(results.vinfo, "\n")
        println(io, "        ", l)
    end
end


