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

## TLS Server

Pass `certfile` and `keyfile` to enable TLS with ALPN `h2`:

```julia
server = HTTP2Server(8443;
    certfile="cert.pem",
    keyfile="key.pem") do req
    ServerResponse(200, "Hello HTTPS/2!")
end
```

For testing with self-signed certificates, use `verify_peer=false` on the client:

```julia
client = HTTP2Client("localhost"; port=8443, verify_peer=false)
resp = get(client, "/")
close(client)
```

!!! note "Implementation detail"
    Server-side TLS is provided by [Reseau.jl](https://github.com/JuliaServices/Reseau.jl),
    whose `TLS.listen` / `TLS.accept` drive the handshake to completion
    internally. ALPN `h2` is advertised via `TLS.Config(alpn_protocols = ["h2"])`.

## Testing from a Browser

Browsers (Chrome, Firefox, Safari, Edge) only negotiate HTTP/2 over TLS with
ALPN — **none of them support h2c (plaintext HTTP/2)**. A cleartext
`HTTP2Server(8080)` is therefore only reachable from clients such as
`curl --http2-prior-knowledge` or Nghttp2Wrapper's own `HTTP2Client`. To try
the server from a browser, start it on TLS instead:

```julia
using Nghttp2Wrapper

server = HTTP2Server(8443;
    certfile="test/fixtures/server.crt",
    keyfile="test/fixtures/server.key") do req
    ServerResponse(200, "Hello HTTP/2!")
end
```

Then open <https://localhost:8443> and accept the self-signed certificate
warning. To confirm HTTP/2 is actually being used, open the browser DevTools
Network tab and enable the "Protocol" column — requests should show `h2`.

A ready-to-run version of this is available at
[`examples/browser_hello.jl`](https://github.com/s-celles/Nghttp2Wrapper.jl/blob/main/examples/browser_hello.jl):

```sh
julia --project=. examples/browser_hello.jl
```

!!! warning "Test certificate only"
    The certificate under `test/fixtures/` is a self-signed development
    certificate. Never use it for anything beyond local experimentation.
