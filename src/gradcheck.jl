using FiniteDifferences
export jacobian, gradcheck

# Base on torch.gradcheck
make_jacobian(x::AbstractArray{T}, out_length::Int) where T = zeros(T, out_length, length(x))
make_jacobian(x::Number, out_length::Int) = zeros(typeof(x), out_length, 1)

zero_like(x::T) where {T <: Number} = zero(T)
zero_like(x) = fill!(similar(x), 0)
zero_like(x::Broadcast.Broadcasted) = zero_like(Broadcast.materialize(x))

"""
    jacobian(f, xs...)

Return the analytical jacobian of `f` with input `xs...`.
"""
function jacobian(f, xs...)
    output, back = pullback(f, xs...)
    output_size = length(output)
    jacobians = map(x->make_jacobian(x, output_size), xs)
    grad_output = zero_like(output)
    jacobian!(back, jacobians, grad_output)
    return jacobians
end

# to get numbers through
_vec(x) = x
_vec(x::AbstractArray) = vec(x)

function jacobian!(f_back, jacobians, grad_output::T) where T <: Number    
    grads_input = f_back(one(T))
    for (jacobian_x, d_x) in zip(jacobians, grads_input)
        jacobian_x[1, :] .= _vec(d_x)
    end
    return jacobians
end

function jacobian!(f_back, jacobians, grad_output::AbstractArray)
    for idx in eachindex(grad_output)
        grad_output = fill!(grad_output, 0)
        grad_output[idx] = 1
        grads_input = f_back(grad_output)
        for (jacobian_x, d_x) in zip(jacobians, grads_input)
            jacobian_x[idx, :] .= _vec(d_x)
        end
    end
    return jacobians
end


"""
    gradcheck(f, xs...; eps=sqrt(eps), atol::Real=0, rtol::Real=atol>0 ? 0 : √eps)

Check the gradient of `f` at input `xs...` by comparing numerical jacobian and analytical jacobian.
"""
function gradcheck(f, xs...;
        eps=sqrt(eps(eltype(first(xs)))),
        atol::Real=0, rtol::Real= atol > 0 ? 0 : sqrt(eps))
    
    fdm = central_fdm(5, 1, eps=eps)
    njac = FiniteDifferences.jacobian(fdm, f, xs...)
    jac = jacobian(f, xs...)
    all( isapprox.(njac, jac, ; atol=atol, rtol=rtol) )
end
