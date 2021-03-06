using BenchmarkTools
export @benchgroup, @bench, root_group

const _benchmark_stack = Any[BenchmarkGroup()]

_reset_stack() = (empty!(_benchmark_stack); push!(_benchmark_stack, BenchmarkGroup()))
_top_group() = _benchmark_stack[end]
_push_group!(g) = push!(_benchmark_stack, g)
_pop_group!() = pop!(_benchmark_stack)

root_group() = _top_group()

macro benchgroup(expr...)
    name = expr[1]
    tags = length(expr) == 3 ? expr[2] : :([])
    grp = expr[end]
    quote
        g = BenchmarkGroup($(esc(tags)))
        _top_group()[$(esc(name))] = g
        _push_group!(g)
        $(esc(grp))
        _pop_group!()
    end
end

ok_to_splat(x) = (x,)
ok_to_splat(x::Tuple) = x

macro bench(expr...)
    id = expr[1]
    bexpr = expr[2:end]
    b = :(BenchmarkTools.@benchmarkable $(bexpr...))

    quote
        _top_group()[ok_to_splat($(esc(id)))...] = $(esc(b))
    end
end
