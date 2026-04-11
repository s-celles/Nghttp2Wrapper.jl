# Low-Level API Guide

Nghttp2Wrapper.jl exposes the complete nghttp2 C API for advanced use cases.

## Version Information

```julia
using Nghttp2Wrapper

info_ptr = nghttp2_version()
info = unsafe_load(info_ptr)
println("nghttp2 version: ", unsafe_string(info.version_str))
```

## Error Handling

```julia
# Convert error codes to strings
msg = nghttp2_strerror(NGHTTP2_ERR_INVALID_ARGUMENT)

# Check if an error is fatal
nghttp2_is_fatal(NGHTTP2_ERR_NOMEM)  # true
nghttp2_is_fatal(NGHTTP2_ERR_WOULDBLOCK)  # false
```

## Wrapper Types (Milestone 2)

Safe wrapper types with automatic resource cleanup:

```julia
# Session with automatic cleanup
cb = Callbacks()
session = Session(cb)
submit_settings!(session)
data = send!(session)
close(session)  # explicit close, or let GC handle it
```

## HPACK Compression

Compress and decompress HTTP headers:

```julia
# Compress
deflater = HpackDeflater()
headers = [NVPair(":method", "GET"), NVPair(":path", "/")]
compressed = deflate(deflater, headers)

# Decompress
inflater = HpackInflater()
recovered = inflate(inflater, compressed)
# recovered == [NVPair(":method", "GET"), NVPair(":path", "/")]

close(deflater)
close(inflater)
```

## Header Validation

```julia
nghttp2_check_header_name("content-type")   # true
nghttp2_check_header_name("Content-Type")   # false (uppercase not allowed in HTTP/2)
nghttp2_check_header_value("text/html")     # true
nghttp2_check_authority("example.com:443")  # true
nghttp2_check_path("/index.html")           # true
nghttp2_check_method("GET")                 # true
```

## Custom Transport

The Session API works with any IO stream, not just TLS connections. Use `send!` and `recv!` to exchange bytes with your transport:

```julia
using Nghttp2Wrapper, Sockets

# Create a session
cb = Callbacks()
session = Session(cb)

# Submit settings
submit_settings!(session)

# Get serialized bytes to send over your transport
outgoing_bytes = send!(session)
# write(your_transport, outgoing_bytes)

# Feed incoming bytes from your transport
# incoming = read(your_transport, ...)
# recv!(session, incoming)

close(session)
```

This enables use with custom transports, proxies, or testing frameworks.

## Raw ccall Bindings (Milestone 1)

For maximum control, use the raw ccall functions directly:

```julia
# Create callbacks
rv, callbacks_ptr = nghttp2_session_callbacks_new()

# Create session
rv, session_ptr = nghttp2_session_client_new(callbacks_ptr)

# Submit settings
nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                        Ptr{Nghttp2SettingsEntry}(C_NULL), 0)

# Send data
nbytes, data_ptr = nghttp2_session_mem_send2(session_ptr)

# Clean up
nghttp2_session_del(session_ptr)
nghttp2_session_callbacks_del(callbacks_ptr)
```
