"""
    Response(status, headers, body)

Represents an HTTP/2 response.

# Fields
- `status::Int` — HTTP status code (e.g., 200, 404)
- `headers::Vector{NVPair}` — Response headers
- `body::Vector{UInt8}` — Response body
"""
struct Response
    status::Int
    headers::Vector{NVPair}
    body::Vector{UInt8}
end

function Base.show(io::IO, r::Response)
    print(io, "Response($(r.status), $(length(r.headers)) headers, $(length(r.body)) bytes)")
end
