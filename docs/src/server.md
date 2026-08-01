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

## Trailers

A trailing HEADERS block is sent *after* the response body and closes the
stream (RFC 7540 §8.1). `nghttp2_submit_trailer` submits one:

```julia
nghttp2_submit_trailer(session, stream_id, [NVPair("grpc-status", "0")])
```

nghttp2 sets END_STREAM on the frame itself, so there is no flag argument. It
validates `stream_id` eagerly — submitting on stream 0 returns
`NGHTTP2_ERR_INVALID_ARGUMENT` (-501) — but defers the "does this stream exist"
check to send time, so a positive id is accepted at submission even if the
stream was never opened.

This is what gRPC responses require: the status travels in the trailers, not in
the response headers, so a server that cannot emit them cannot complete a gRPC
call.

From a handler, return them on the response:

```julia
server = HTTP2Server(8080) do req
    ServerResponse(200, "payload"; trailers = [NVPair("grpc-status", "0")])
end
```

The last DATA frame is then flagged `NGHTTP2_DATA_FLAG_NO_END_STREAM`, so the
body does not close the stream — the trailers do. A trailers-only response
(empty body) works too.

!!! note "Streaming is still buffered"
    The handler returns a complete `ServerResponse`: the whole request body
    arrives before it runs, and the whole response body is returned at once.
    That is enough for a unary request/response exchange with trailers, but not
    for emitting messages incrementally. An incremental handler model is on the
    roadmap.

## Server Settings

A server sends its HTTP/2 SETTINGS on every new connection. By default it sends
an empty frame — the required handshake and nothing more. Name what you want and
only that is sent:

```julia
server = HTTP2Server(8080; max_concurrent_streams = 100,
                           initial_window_size = 1 << 20) do req
    ServerResponse(200, "OK")
end
```

Available: `max_concurrent_streams`, `initial_window_size`, `max_frame_size` and
`max_header_list_size`. A setting left unset is not sent, so protocol defaults
apply. For anything outside these four, `nghttp2_submit_settings` is exported.

## Knowing Who Is Calling

`peer_address` returns the remote endpoint of the connection a request arrived
on, as a `Sockets.InetAddr`:

```julia
server = HTTP2Server(8080) do req
    @info "request" from = peer_address(req) path = req.path
    ServerResponse(200, "OK")
end
```

It works for both listener kinds and for incremental handlers
(`peer_address(stream)`). It returns `nothing` when the endpoint cannot be
resolved — a peer that has already gone, say — rather than a fabricated
address, so a caller rate-limiting or logging on it can tell the difference.

## Incremental Handlers

The handler shown above is *buffered*: it receives a complete `ServerRequest` and
returns a complete `ServerResponse`. That is enough whenever the response is one
piece, but it cannot emit messages as they are produced — the reply only reaches
the peer once the handler returns.

Pass `streaming = true` and the handler receives a [`ServerStream`](@ref)
instead:

```julia
server = HTTP2Server(8080; streaming = true) do stream
    setstatus(stream, 200)
    setheader(stream, "content-type", "text/event-stream")
    for i in 1:5
        write(stream, Vector{UInt8}("event $i\n"))
        sleep(1)
    end
end
```

Each `write` reaches the peer when it happens, not five seconds later.

`ServerStream` subtypes `IO`, so the request side needs no new vocabulary —
`eof`, `read`, `readavailable` and `readbytes!` mean what they already mean —
and the request head is available through `request_method`, `request_path` and
`request_headers`.

The response is submitted on the first `write` or when the handler returns,
whichever comes first. That is why status and headers must be staged **before**
the first write: afterwards the headers are already on the wire.

!!! warning "`read(stream, n)` returns *at most* `n` bytes"
    As for any `IO`. A short read is neither an error nor end-of-stream — it
    means that much was buffered. Loop until you have what you need, or until
    the peer half-closes. Assuming otherwise caps every request at the HTTP/2
    flow-control window.

Trailers work as they do for buffered responses: `settrailer` stages a trailing
HEADERS block, and it — not the body — closes the stream.

```julia
server = HTTP2Server(8080; streaming = true) do stream
    setstatus(stream, 200)
    write(stream, payload)
    settrailer(stream, NVPair("grpc-status", "0"))
end
```

A handler that throws still terminates its stream: the status becomes 500 if it
had not set one, and the stream is closed, so the peer is never left waiting.

`close(server)` waits for incremental handlers in flight just as it does for
buffered ones, up to its `timeout`.

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
