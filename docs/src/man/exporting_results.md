# Exporting results from a single benchmark run

Results from running [`benchmark`](@ref) can be exported to markdown using [`export_markdown`](@ref).
For example

```julia-repl
julia> results = benchmark("PkgBenchmark")

julia> export_markdown("results.md", results)
```

The markdown file includes some metadata, and information about the time, GC time, memory, number of allocations for all the benchmarks.
An example of the rendered markdown file can be seen [here](https://gist.github.com/KristofferC/04eab1a7043a3be5d66240f27a381892).

# Exporting results from a comparison

