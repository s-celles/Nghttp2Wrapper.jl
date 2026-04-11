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
end

function ServerResponse(status::Integer; headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    ServerResponse(Int(status), headers, body)
end

function ServerResponse(status::Integer, body::AbstractString)
    ServerResponse(Int(status), NVPair[], Vector{UInt8}(body))
end

function Base.show(io::IO, r::ServerResponse)
    print(io, "ServerResponse($(r.status), $(length(r.headers)) headers, $(length(r.body)) bytes)")
end
