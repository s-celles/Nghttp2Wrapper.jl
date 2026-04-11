# Advanced Features

## Connection Pooling

Reuse connections across requests to avoid repeated TLS handshakes:

```julia
using Nghttp2Wrapper

pool = ConnectionPool(max_per_host=6, idle_timeout=60.0)

# Connections are automatically acquired and released
resp1 = pool_get(pool, "https://nghttp2.org/")
resp2 = pool_get(pool, "https://nghttp2.org/page2")  # reuses same connection

close(pool)
```

### Manual Acquire/Release

```julia
client = acquire(pool, "nghttp2.org")
resp = get(client, "/")
release(pool, client)  # returns to pool for reuse
```

## HPACK Dynamic Table Inspection

```julia
d = HpackDeflater(8192)
println(dynamic_table_size(d))  # 8192
entries = inspect_dynamic_table(d)
close(d)
```

## Stream Priority

Set HTTP/2 stream priorities on requests:

```julia
priority = PrioritySpec(weight=32, exclusive=true)
# Priority can be passed to low-level submit functions
```

## HTTP/2 Proxy Pattern

Forward requests between server and client sessions:

```julia
# In a server handler:
upstream = HTTP2Client("upstream-server.com")
server = HTTP2Server(8080) do req
    forward_request(upstream, req)
end
```

## WebSocket over HTTP/2

Initiate WebSocket tunnels via Extended CONNECT (RFC 8441):

```julia
client = HTTP2Client("ws-server.com")
stream_id = websocket_connect(client, "/ws")
# Note: Requires server support for RFC 8441
```
