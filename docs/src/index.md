# Nghttp2Wrapper.jl

A Julia wrapper for the [nghttp2](https://nghttp2.org/) HTTP/2 C library, using [`nghttp2_jll`](https://github.com/JuliaBinaryWrappers/nghttp2_jll.jl).

## Overview

Nghttp2Wrapper.jl provides Julia bindings to nghttp2, an implementation of HTTP/2 and its header compression algorithm HPACK (RFC 7540, RFC 7541).

**Features:**

- Low-level `ccall` bindings to the complete nghttp2 C API
- Safe Julia wrapper types with automatic resource management (finalizers)
- High-level HTTP/2 client with TLS/ALPN, multiplexing, and streaming
- HTTP/2 server with request handler callback interface
- HPACK header compression/decompression
- Header validation utilities

## Installation

```julia
using Pkg
Pkg.add("Nghttp2Wrapper")  # when registered in Julia General Registry
```

## Quick Start

```julia
using Nghttp2Wrapper

# Make an HTTP/2 GET request
client = HTTP2Client("nghttp2.org")
response = get(client, "/")
println("Status: ", response.status)
println("Body: ", length(response.body), " bytes")
close(client)
```

## Known Limitations

- **Request body streaming**: Sending large request bodies incrementally is not yet supported. Complete request bodies are sent at once.
- **HTTP.jl integration**: Integration as an HTTP/2 layer for HTTP.jl is planned for a future release.

See the [API Reference](api.md) for the complete list of exported functions and types.
