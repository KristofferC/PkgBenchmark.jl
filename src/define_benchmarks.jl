##################
# Dict based API #
##################
SUITE = nothing

"""
    register_suite(suite::BenchmarkGroup)

Registers the benchmark suite `suite` with PkgBenchmark so that it is used
when running [`benchmark`](@ref).
"""
function register_suite(bg::BenchmarkGroup)
    global SUITE = bg
end

_reset_suite() = global SUITE = nothing
_get_suite() = SUITE

###################
# Macro based API #
###################
const _benchmark_stack = Any[BenchmarkGroup()]

_reset_stack() = (empty!(_benchmark_stack); push!(_benchmark_stack, BenchmarkGroup()))
_top_group() = _benchmark_stack[end]
_push_group!(g) = push!(_benchmark_stack, g)
_pop_group!() = pop!(_benchmark_stack)
_root_group() = _top_group()

"""
    @benchgroup <name> [<tags>] begin
        <expr>
    end

Define a benchmark group. It can contain nested `@benchgroup` and `@bench` expressions.
`<name>` is a string naming the benchmark group. `<tags>` is a vector of strings, tags for the benchmark group,
and is optional. `<expr>` are expressions that can contain `@benchgroup` or `@bench` calls.
"""
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

"""
    @bench <name>... <expr>

Creates a benchmark under the current `@benchgroup`.
`<name>` is a name/id for the benchmark, the last argument to `@bench`, `<expr>`, is the expression to be benchmarked, 
and has the same [interpolation features](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#interpolating-values-into-benchmark-expressions)
as the `@benchmarkable` macro from BenchmarkTools.
"""
macro bench(expr...)
    id = expr[1]
    bexpr = expr[2:end]
    b = :(BenchmarkTools.@benchmarkable $(bexpr...))

    quote
        _top_group()[ok_to_splat($(esc(id)))...] = $(esc(b))
    end
end
