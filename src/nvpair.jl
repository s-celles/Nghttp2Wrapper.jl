"""
    NVPair(name, value)

An HTTP header name-value pair. Owns copies of the name and value
as byte vectors, ensuring memory safety when passed to C functions.

# Examples
```julia
nv = NVPair(":method", "GET")
nv = NVPair(":path", "/index.html")
```
"""
struct NVPair
    name::Vector{UInt8}
    value::Vector{UInt8}
end

NVPair(name::AbstractString, value::AbstractString) = NVPair(Vector{UInt8}(name), Vector{UInt8}(value))

function Base.show(io::IO, nv::NVPair)
    print(io, "NVPair(\"", String(copy(nv.name)), "\" => \"", String(copy(nv.value)), "\")")
end

"""
    to_nghttp2_nv(nv::NVPair) → Nghttp2Nv

Convert an NVPair to the C-compatible Nghttp2Nv struct.
The caller MUST ensure the NVPair remains alive (GC.@preserve)
for the duration of any C call using the returned struct.
"""
function to_nghttp2_nv(nv::NVPair)
    Nghttp2Nv(pointer(nv.name), pointer(nv.value),
              Csize_t(length(nv.name)), Csize_t(length(nv.value)),
              NGHTTP2_NV_FLAG_NONE)
end

"""
    with_nva(f, pairs::Vector{NVPair})

Convert a vector of NVPairs to a C-compatible array of Nghttp2Nv structs,
call `f(nva_ptr, nvlen)`, and return the result. The NVPair data is
GC-preserved for the duration of the call.
"""
function with_nva(f, pairs::Vector{NVPair})
    nva = [to_nghttp2_nv(nv) for nv in pairs]
    GC.@preserve pairs nva begin
        return f(pointer(nva), length(nva))
    end
end

"""
    nghttp2_submit_trailer(session, stream_id, pairs::Vector{NVPair}) → Cint

Convenience overload of the pointer-level entry point in `frames.jl`, taking
`NVPair`s. Defined here rather than beside it because `NVPair` and `with_nva`
are introduced by this file, which is included later.

The underlying name/value buffers are GC-preserved for the duration of the call.
"""
function nghttp2_submit_trailer(session::Ptr{Cvoid}, stream_id::Integer,
                                 pairs::Vector{NVPair})
    with_nva(pairs) do nva_ptr, nvlen
        nghttp2_submit_trailer(session, stream_id, nva_ptr, nvlen)
    end
end
