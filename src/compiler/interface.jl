mutable struct Context <: AContext
  cache::Union{IdDict{Any,Any},Nothing}
end

Context() = Context(nothing)

cache(cx::Context) = cx.cache === nothing ? (cx.cache = IdDict()) : cx.cache

struct Pullback{S,T}
  t::T
end

Pullback{S}(x) where S = Pullback{S,typeof(x)}(x)

struct CompileError
  T
  e
end

function Base.showerror(io::IO, e::CompileError)
  print(io, "Compiling $(e.T): ")
  showerror(io, e.e)
end

# interface2.jl

# Wrappers

_pullback(f, args...) = _pullback(Context(), f, args...)

tailmemaybe(::Nothing) = nothing
tailmemaybe(x::Tuple) = Base.tail(x)

function pullback(f, args...)
  y, back = _pullback(f, args...)
  y, Δ -> tailmemaybe(back(Δ))
end

sensitivity(y::Number) = one(y)
sensitivity(y::Complex) = error("Output is complex, so the gradient is not defined.")
sensitivity(y) = error("Output should be scalar; gradients are not defined for output $(repr(y))")

function gradient(f, args...)
  y, back = pullback(f, args...)
  return back(sensitivity(y))
end

Base.adjoint(f::Function) = x -> gradient(f, x)[1]

# Code Reflection

using InteractiveUtils
using InteractiveUtils: typesof
using Core: Typeof

function code_ir(f, T)
  m = meta(Tuple{Typeof(f),T.parameters...})
  return IR(m)
end

function code_irm(ex)
  isexpr(ex, :call) || error("@code_ir f(args...)")
  f, args = ex.args[1], ex.args[2:end]
  :(code_ir($(esc(f)), typesof($(esc.(args)...))))
end

macro code_ir(ex)
  code_irm(ex)
end

macro code_adjoint(ex)
  :(Adjoint($(code_irm(ex)), varargs = varargs($(esc(:($InteractiveUtils.@which $ex))), length(($(esc.(ex.args)...),)))))
end
