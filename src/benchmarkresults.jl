struct BenchmarkResult
    benchmarkconfig::BenchmarkConfig
    benchmarkgroup::BenchmarkGroup
    date::DateTime
    vinfo::String
end

function Base.show(io::IO, results::BenchmarkResult)
    println(io, "Benchmarkresults")
    println(io, "    Date: ", results.date)
    println(io, "    Commit: ")
    println(io, "    Versioninfo: ")
    for l in split(results.vinfo, "\n")
        println(io, "        ", l)
    end
end


