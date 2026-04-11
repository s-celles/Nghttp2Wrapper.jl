# HTTP/2 Client Guide

## Creating a Connection

Connect to an HTTPS HTTP/2 server:

```julia
using Nghttp2Wrapper

client = HTTP2Client("nghttp2.org")
# ... use client ...
close(client)
```

### Connection Options

```julia
client = HTTP2Client("example.com";
    port=443,                      # default
    max_concurrent_streams=100,    # default
    initial_window_size=65535,     # default
    header_table_size=4096,        # default
    verify_peer=true               # set false for self-signed certs
)
```

## Making Requests

### GET Request

```julia
response = get(client, "/")
println(response.status)     # 200
println(response.headers)    # Vector{NVPair}
println(String(response.body))
```

### POST Request

```julia
response = post(client, "/api/data";
    headers=[NVPair("content-type", "application/json")],
    body=Vector{UInt8}("{\"key\": \"value\"}")
)
```

### Other Methods

```julia
put(client, "/resource"; body=...)
delete(client, "/resource")
patch(client, "/resource"; body=...)
head(client, "/resource")
options(client, "/resource")
```

### Generic Request

```julia
response = request(client, "GET", "/path";
    headers=[NVPair("accept", "text/html")],
    body=UInt8[]
)
```

## Custom Headers

```julia
headers = [
    NVPair("user-agent", "MyApp/1.0"),
    NVPair("accept", "application/json"),
]
response = get(client, "/api"; headers=headers)
```

## Concurrent Requests (Multiplexing)

HTTP/2 supports multiple concurrent requests on a single connection:

```julia
client = HTTP2Client("nghttp2.org")

# Launch concurrent requests
tasks = [
    @async get(client, "/page1"),
    @async get(client, "/page2"),
    @async get(client, "/page3"),
]

# Collect responses
responses = [fetch(t) for t in tasks]
for r in responses
    println("Status: ", r.status)
end

close(client)
```

## Streaming Responses

For large responses, receive data incrementally:

```julia
done_ch, chunks_ch = request_stream(client, "GET", "/large-file")

for chunk in chunks_ch
    # Process each chunk as it arrives
    println("Received ", length(chunk), " bytes")
end

# Get final response with headers
response = take!(done_ch)
println("Status: ", response.status)
```

## Error Handling

All client operations throw `Nghttp2Error` on failure:

```julia
try
    response = get(client, "/")
catch e
    if e isa Nghttp2Error
        println("Error code: ", e.code)
        println("Message: ", e.msg)
        println("Fatal: ", e.fatal)
    end
end
```

## Graceful Shutdown

```julia
shutdown!(client)  # sends GOAWAY, waits for pending requests
```

## Connection Lifecycle

```julia
client = HTTP2Client("example.com")
println(isopen(client))  # true
close(client)
println(isopen(client))  # false
```
