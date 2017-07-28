# Defining a benchmark suite

Benchmarks are to be written in `<PKGROOT>/benchmark/benchmarks.jl`, where `<PKGROOT>` is the path to the package and can be defined in two different ways:

* Using the standard dictionary based interface from BenchmarkTools, as documented [here](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#defining-benchmark-suites). Note that the suite need to be registered with PkgBenchmark by calling `register_suite(SUITE)`. An example file using the dictionary based interface can be found [here](https://github.com/JuliaCI/PkgBenchmark.jl/blob/master/benchmark/benchmarks_dict.jl).
* Using the `@benchgroup` and `@bench` macros. These are analogous to `@testset` and `@test` macros, with slightly different syntax. An example file using the macro based interface can be found [here](https://github.com/JuliaCI/PkgBenchmark.jl/blob/master/benchmark/benchmarks.jl).

## Using the macro based API

Two macros are provided, mirroring those of `@testset` and `@test`:

```@docs
@benchgroup
```

```@docs
@bench
```

### Example

An example `benchmark/benchmarks.jl` script would look like:

```@eval
Base.Markdown.parse("```julia\n$(readstring(joinpath(dirname(@__FILE__), "..", "benchmark/benchmarks.jl")))```")
```

!!! note
    Running this script directly does not actually run the benchmarks,
    see the section [Running a benchmark suite](@ref).

## Customizing REQUIRE for the benchmarks

The file `<PKGROOT>/benchmark/REQUIRE` can be used to define extra dependencies needed to run the benchmark suite.
