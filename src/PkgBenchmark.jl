__precompile__()

module PkgBenchmark

using BenchmarkTools
using FileIO
using JLD

export @benchgroup, @bench, register_suite
export benchmark, judge, export_markdown, readresults
export BenchmarkConfig, BenchmarkResult

include("util.jl")
include("define_benchmarks.jl")
include("benchmarkconfig.jl")
include("benchmarkresults.jl")
include("runbenchmark.jl")
include("judge.jl")

end # module
