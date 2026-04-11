"""
    PrioritySpec(; dep_stream=0, weight=16, exclusive=false)

HTTP/2 stream priority specification.

# Fields
- `dep_stream::Int32` — dependent stream ID (0 = root)
- `weight::Int32` — priority weight (1-256, default 16)
- `exclusive::Bool` — exclusive dependency flag
"""
struct PrioritySpec
    dep_stream::Int32
    weight::Int32
    exclusive::Bool
end

function PrioritySpec(; dep_stream::Integer=0, weight::Integer=16, exclusive::Bool=false)
    PrioritySpec(Int32(dep_stream), Int32(weight), exclusive)
end

function Base.show(io::IO, p::PrioritySpec)
    print(io, "PrioritySpec(weight=$(p.weight), dep=$(p.dep_stream), exclusive=$(p.exclusive))")
end
