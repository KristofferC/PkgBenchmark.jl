"""
    judge(pkg::String, target::BenchmarkConfig, baseline::BenchmarkConfig;
          judge_kwargs::Dict=Dict(), kwargs...)

Judges the results of benchmarking `target` against `baseline` for package `pkg`.

**Arguments**:

- `pkg` is the package to benchmark
- `target` the commit to judge. If skipped, use the current state of the package repo.
- `baseline` is the commit to compare `ref` against.

Keyword arguments are passed to [`benchmark`](@ref)
"""
function BenchmarkTools.judge(pkg::String, target = BenchmarkConfig(), baseline = BenchmarkConfig();
                              f=minimum, used_saved=true, resultsdir = defaultresultsdir(pkg), judge_kwargs = Dict(), kwargs...)
    target, baseline = BenchmarkConfig(target), BenchmarkConfig(baseline)

    function cached(ref; kws...)
        if ref.id !== nothing
            __filename = _filename(pkg, ref)
            if isfile(__filename)
                benchinfo("Loading stored results from $resultsdir.")
                return load(File(format"JLD", __filename))["results"]
            end
        end
        return benchmark(pkg, ref; kws...)
    end

    result_ref1 = cached(target; kwargs...)
    result_ref2 = cached(baseline; kwargs...)

    return judge(result_ref1, result_ref2; f = f, judge_kwargs = judge_kwargs)
end

function BenchmarkTools.judge(target::BenchmarkResult, baseline::BenchmarkResult;
                              f = minimum, judge_kwargs = Dict())
        
        BenchmarkTools.judge(f(benchmarkgroup(target)), 
                             f(benchmarkgroup(baseline)); judge_kwargs...)

end