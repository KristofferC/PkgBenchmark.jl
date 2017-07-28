"""
    BenchmarkResult

Stores the result from running the benchmarks on a package.

The following (unexported) methods are defined on a `BenchmarkResult` (written below as `result`):

* `date(result)::DateTime` - the time when the benchmarks were executed
* `versioninfo(result)::String` - the versioninfo of the julia instance that ran the benchmarks
* `benchmarkconfig(result)::BenchmarkConfig` - the [`benchmarkconfig`](@ref) of the 
* `benchmarkgroup(result)::BenchmarkGroup` - a [`BenchmarkGroup`](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#the-benchmarkgroup-type)
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
    println(io, "Benchmarkresult")
    println(io, "    Package: ", results.benchmarkconfig._pkgname)
    println(io, "    Date: ", Base.Dates.format(results.date, "m u Y - H:M"))
    print(io, "    Commit: ", results.benchmarkconfig._commit)
    # println(io, "    Versioninfo: ")
    # for l in split(results.vinfo, "\n")
    #     println(io, "        ", l)
    # end
end


"""
    export_markdown(file::String, results::BenchmarkResult)
    export_markdown(io::IO, results::BenchmarkResult)

Writes the `results` to `file` or `io` in markdown format.

See also: [`BenchmarkResult`](@ref)
"""
function export_markdown(file::String, results::BenchmarkResult)
    open(file, "w") do f
        export_markdown(f, results)
    end
end

function export_markdown(io::IO, results::BenchmarkResult)
    println(io, """
                # Benchmark Report for *$(results.benchmarkconfig._pkgname)*
                
                ## Job Properties
                * Time of benchmark: $(Base.Dates.format(results.date, "m u Y - H:M"))
                * Package commit(s): $(results.benchmarkconfig._commit) 
                """)

      println(io, """
                ## Results
                Below is a table of this job's results, obtained by running the benchmarks.
                The values listed in the `ID` column have the structure `[parent_group, child_group, ..., key]`, and can be used to 
                index into the BaseBenchmarks suite to retrieve the corresponding benchmarks.
                The percentages accompanying time and memory values in the below table are noise tolerances. The "true"
                time/memory value for a given benchmark is expected to fall within this percentage of the reported value.
                """)

    print(io, """
                | ID | time | GC time | memory | allocations |
                |----|------|---------|--------|-------------|
                """)

    entries = BenchmarkTools.leaves(benchmarkgroup(results))
    try
        entries = entries[sortperm(map(x -> string(first(x)), entries))]
    end


    for (ids, t) in entries
        if true #!(iscomparisonjob) || BenchmarkTools.isregression(t) || BenchmarkTools.isimprovement(t)
            println(io, resultrow(ids, t))
        end
    end
    println(io)

        # print list of executed benchmarks #
    #-----------------------------------#
    println(io, """
                ## Benchmark Group List
                Here's a list of all the benchmark groups executed by this job:
                """)

    for id in unique(map(pair -> pair[1][1:end-1], entries))
        println(io, "- `", idrepr(id), "`")
    end

    println(io)

    println(io, "## Versioninfo")
    print(io, "```\n", versioninfo(results), "```")

    return nothing

end

idrepr(id) = (str = repr(id); str[searchindex(str, '['):end])
intpercent(p) = string(ceil(Int, p * 100), "%")
resultrow(ids, t::BenchmarkTools.Trial) = resultrow(ids, minimum(t))

function resultrow(ids, t::BenchmarkTools.TrialEstimate)
    t_tol = intpercent(BenchmarkTools.params(t).time_tolerance)
    m_tol = intpercent(BenchmarkTools.params(t).memory_tolerance)
    timestr = string(BenchmarkTools.prettytime(BenchmarkTools.time(t)), " (", t_tol, ")")
    memstr = string(BenchmarkTools.prettymemory(BenchmarkTools.memory(t)), " (", m_tol, ")")
    gcstr = BenchmarkTools.prettytime(BenchmarkTools.gctime(t))
    allocstr = string(BenchmarkTools.allocs(t))
    return "| `$(idrepr(ids))` | $(timestr) | $(gcstr) | $(memstr) | $(allocstr) |"
end

function resultrow(ids, t::BenchmarkTools.TrialJudgement)
    t_tol = intpercent(BenchmarkTools.params(t).time_tolerance)
    m_tol = intpercent(BenchmarkTools.params(t).memory_tolerance)
    t_ratio = @sprintf("%.2f", BenchmarkTools.time(BenchmarkTools.ratio(t)))
    m_ratio =  @sprintf("%.2f", BenchmarkTools.memory(BenchmarkTools.ratio(t)))
    t_mark = resultmark(BenchmarkTools.time(t))
    m_mark = resultmark(BenchmarkTools.memory(t))
    timestr = "$(t_ratio) ($(t_tol)) $(t_mark)"
    memstr = "$(m_ratio) ($(m_tol)) $(m_mark)"
    return "| `$(idrepr(ids))` | $(timestr) | $(memstr) |"
end

resultmark(sym::Symbol) = sym == :regression ? REGRESS_MARK : (sym == :improvement ? IMPROVE_MARK : "")