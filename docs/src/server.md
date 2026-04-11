# HTTP/2 Server Guide

## Creating a Server

```julia
using Nghttp2Wrapper

server = HTTP2Server(8080) do req
    ServerResponse(200, "Hello HTTP/2!")
end

# Server is now listening on port 8080
# Press Ctrl+C or call close(server) to stop
```

## Request Handler

The handler function receives a `ServerRequest` and returns a `ServerResponse`:

```julia
function my_handler(req::ServerRequest)
    println("$(req.method) $(req.path)")
    
    if req.path == "/"
        return ServerResponse(200, "Welcome!")
    elseif req.path == "/api/data"
        headers = [NVPair("content-type", "application/json")]
        return ServerResponse(200, headers, Vector{UInt8}("{\"status\": \"ok\"}"))
    else
        return ServerResponse(404, "Not Found")
    end
end

server = HTTP2Server(my_handler, 8080)
```

### ServerRequest Fields

- `method::String` — HTTP method (GET, POST, etc.)
- `path::String` — Request path
- `headers::Vector{NVPair}` — Request headers
- `body::Vector{UInt8}` — Request body
- `stream_id::Int32` — HTTP/2 stream ID

### ServerResponse Construction

```julia
# Status only
ServerResponse(200)

# Status + string body
ServerResponse(200, "Hello!")

# Status + headers + body
ServerResponse(200,
    [NVPair("content-type", "text/plain")],
    Vector{UInt8}("Hello!")
)
```

## Concurrent Connections

The server handles multiple clients concurrently using a task-per-connection model:

```julia
server = HTTP2Server(8080) do req
    # This handler may be called from multiple tasks concurrently
    # Each connection runs in its own task
    ServerResponse(200, "Response for $(req.path)")
end
```

## Error Handling

If your handler throws an exception, the server catches it and returns a 500 response. The server continues running:

```julia
server = HTTP2Server(8080) do req
    error("Something went wrong")
    # Client receives: ServerResponse(500, "Internal Server Error")
    # Server keeps running
end
```

## Graceful Shutdown

```julia
shutdown!(server)  # stops accepting, waits for in-flight requests
```

Or immediate close:

```julia
close(server)
```

## Known Limitation: TLS

The server currently operates in cleartext HTTP/2 (h2c) mode. TLS server support is deferred due to an [OpenSSL.jl upstream issue](https://github.com/s-celles/Nghttp2Wrapper.jl/blob/main/upstream-bugs.md) with server-side TLS accept handling.

For testing, connect using the low-level session API over a plain TCP socket.
