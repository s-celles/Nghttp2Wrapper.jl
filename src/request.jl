"""
    Request(method, path; headers=NVPair[], body=UInt8[])

Represents an outgoing HTTP/2 request.

# Fields
- `method::String` — HTTP method (GET, POST, etc.)
- `path::String` — Request path (e.g., "/index.html")
- `headers::Vector{NVPair}` — Custom request headers
- `body::Vector{UInt8}` — Request body
"""
struct Request
    method::String
    path::String
    headers::Vector{NVPair}
    body::Vector{UInt8}
end

function Request(method::AbstractString, path::AbstractString;
                 headers::Vector{NVPair}=NVPair[],
                 body::Vector{UInt8}=UInt8[])
    Request(String(method), String(path), headers, body)
end

function Request(method::AbstractString, path::AbstractString,
                 headers::Vector{NVPair}, body::AbstractString)
    Request(String(method), String(path), headers, Vector{UInt8}(body))
end

function Base.show(io::IO, r::Request)
    print(io, "Request(\"$(r.method)\", \"$(r.path)\"")
    if !isempty(r.headers)
        print(io, ", $(length(r.headers)) headers")
    end
    if !isempty(r.body)
        print(io, ", $(length(r.body)) bytes body")
    end
    print(io, ")")
end
