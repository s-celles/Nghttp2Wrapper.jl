"""
    ServerRequest(method, path, headers, body, stream_id)

Represents an incoming HTTP/2 request as received by a server handler.
"""
struct ServerRequest
    method::String
    path::String
    headers::Vector{NVPair}
    body::Vector{UInt8}
    stream_id::Int32
end

function Base.show(io::IO, r::ServerRequest)
    print(io, "ServerRequest(\"$(r.method)\", \"$(r.path)\", stream=$(r.stream_id))")
end

"""
    ServerResponse(status; headers=NVPair[], body=UInt8[])
    ServerResponse(status, body::AbstractString)
    ServerResponse(status, headers, body)

Represents an HTTP/2 response to be sent by a server handler.
"""
struct ServerResponse
    status::Int
    headers::Vector{NVPair}
    body::Vector{UInt8}
    trailers::Vector{NVPair}
end

"""
    ServerResponse(status; headers, body, trailers)

`trailers` are sent as a HEADERS block *after* the body, closing the stream
(RFC 7540 §8.1). When it is non-empty the body no longer carries END_STREAM —
the trailers do.

This is what gRPC requires: the call status travels in the trailers, not in the
response headers.
"""
function ServerResponse(status::Integer; headers::Vector{NVPair}=NVPair[],
                        body::Vector{UInt8}=UInt8[],
                        trailers::Vector{NVPair}=NVPair[])
    ServerResponse(Int(status), headers, body, trailers)
end

function ServerResponse(status::Integer, body::AbstractString;
                        trailers::Vector{NVPair}=NVPair[])
    ServerResponse(Int(status), NVPair[], Vector{UInt8}(body), trailers)
end

# Positional form kept for callers predating the trailers field.
ServerResponse(status::Integer, headers::Vector{NVPair}, body::Vector{UInt8}) =
    ServerResponse(Int(status), headers, body, NVPair[])

function Base.show(io::IO, r::ServerResponse)
    print(io, "ServerResponse($(r.status), $(length(r.headers)) headers, $(length(r.body)) bytes",
          isempty(r.trailers) ? "" : ", $(length(r.trailers)) trailers", ")")
end
