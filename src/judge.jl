"""
    judge(pkg, ref, baseline; kwargs...)

You can call `showall(results)` to see a comparison of all the benchmarks.

**Arguments**:

- `pkg` is the package to benchmark
- `ref` optional, the commit to judge. If skipped, use the current state of the package repo.
- `baseline` is the commit to compare `ref` against.

Keyword arguments are passed to [`benchmarkpkg`](@ref)
"""
function BenchmarkTools.judge(pkg::String, ref1 = BenchmarkConfig(), ref2 = BenchmarkConfig(); 
                              f=nothing, used_saved=true, resultsdir = defaultresultsdir(pkg), kwargs...)
    ref1, ref2 = BenchmarkConfig(ref1), BenchmarkConfig(ref2)
    if f != nothing
        Base.warn_once("key word `f` is deprecated and will be removed")
    else
        f = minimum
    end

    function cached(ref; kws...)
        if ref.id !== nothing
            sha = shastring(Pkg.dir(pkg), ref.id)
            file = joinpath(resultsdir, string(_hash(ref, sha), ".jld"))
            if isfile(file)
                info("Loading stored results for $(sha[1:6]) from $resultsdir")
                return readresults(file)
            end
        end
        return benchmarkpkg(pkg, ref; kws...)
    end

    result_ref1 = cached(ref1; kwargs...)
    result_ref2 = cached(ref2; kwargs...)

    return result_ref1, result_ref2
end