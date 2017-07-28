```@meta
DocTestSetup  = quote
    using PkgBenchmark
end
```

# Running a benchmark suite

## Running with default settings

Running a benchmark suite (as described in the section [Defining a benchmark suite](@ref)) with the default settings is done by calling the function
[`benchmark("MyPkg")`](@ref), where `MyPkg` is the name of the package. This will run the benchmarks on the current state of the package
and save the results to a file in the folder `.benchmarks` in the package directory (can be found with `Pkg.dir()`). An example run of a package
is shown below.

```julia-repl
julia> result = benchmark("Tensors");
PkgBenchmark: Running benchmarks.
PkgBenchmark: Using benchmark tuning data in /home/kristoffer/.julia/v0.6/.benchmarks/Tensors/.tune.jld.
PkgBenchmark: Results of the benchmark were written to /home/kristoffer/.julia/v0.6/.benchmarks/Tensors/results/7604238403152958167.jld.

julia> result
Benchmarkresult
    Package: Tensors
    Date: 7 Jul 2017 - 15:36
    Commit: dd6a804b3d4f9703f6f0c2fc2305cb04be8d385e
```

The type of `result` is a [`BenchmarkResult`](@ref) that contains the results of the benchmarks and metadata about the run.
Common usage is to export the `result` to markdown using the [`export_markdown`](@ref) function.

The result can be loaded back with [`readresults`](@ref) as

```julia-repl
julia> readresults("Tensors")
Benchmarkresult
    Package: Tensors
    Date: 7 Jul 2017 - 18:12
    Commit: dd6a804b3d4f9703f6f0c2fc2305cb04be8d385e

```

## Customizing the benchmarking

In addition to the package name, a [`BenchmarkConfig`](@ref) can be passed to the `benchmark` function.
This object contains information about what package commit, what julia command, and what environment variables should
be used when benchmarking. The default values can be seen by using the default constructor

```jldoctest
julia> BenchmarkConfig()
BenchmarkConfig:
    id: nothing
    juliacmd: `/home/user/julia/julia`
    env:
```

The default value of `juliacmd` is `joinpath(JULIA_HOME, Base.julia_exename()` which is the location of the julia executable that is executing the command.
An `id` of `nothing` means that the current state of the package will be benchmarked.

To instead benchmark the branch `PR`, using the julia command `julia -O3`
with the environment variable `JULIA_NUM_THREADS` set to 4, the config would be created as

```jldoctest
julia> config = BenchmarkConfig(id = "PR", juliacmd = `julia -O3`, env = Dict("JULIA_NUM_THREADS" => 4))
BenchmarkConfig:
    id: PR
    juliacmd: `julia -O3`
    env: JULIA_NUM_THREADS => 4
```

To benchmark the package with the config, call `benchmark` as

```julia
benchmark("Tensors", config)
```

!!! info
    The `id` keyword to the `BenchmarkConfig` does not have to be a branch, it can be most things that git can understand, for example a commit id
    or a tag.

When you use a custom `BenchmarkConfig` and want to read back the results from the call to `benchmark`,
you need to pass it as an argument to `readresults` as:

```julia
readresults("Tensors", config)
```

This is because benchmarks with different configs, uses different filenames.

## Advanced usage

See the documentation for [`benchmark`](@ref) for keyword arguments for advanced usage.
