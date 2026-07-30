# Nghttp2Wrapper.jl Roadmap

This document outlines the development roadmap for Nghttp2Wrapper.jl, a Julia wrapper for the [nghttp2](https://nghttp2.org/) C library (HTTP/2 and HPACK implementation) using [nghttp2_jll](https://github.com/JuliaBinaryWrappers/nghttp2_jll.jl) (v1.68.1+0, [JuliaRegistries/General#150873](https://github.com/JuliaRegistries/General/pull/150873)).

---

## Milestone 0 — Project Bootstrap

**Goal:** Set up the project structure, CI, and documentation infrastructure.

- [x] Initialize Julia package structure (`Project.toml`, `src/`, `test/`, `docs/`)
- [x] Add `nghttp2_jll` as a dependency
- [x] Set up GitHub Actions CI (tests on Linux, macOS, Windows)
- [x] Set up Documenter.jl for documentation
- [x] Add `CHANGELOG.md` (Keep a Changelog format)
- [x] Configure test infrastructure with TestItemRunner.jl

---

## Milestone 1 — Low-Level C Bindings (`ccall`)

**Goal:** Expose the raw nghttp2 C API via `ccall` wrappers using `libnghttp2` from nghttp2_jll.

### 1.1 — Library Info & Error Handling

- [x] `nghttp2_version_info()` — retrieve library version
- [x] `nghttp2_strerror()` — error code to string
- [x] `nghttp2_is_fatal()` — check if error is fatal
- [x] Define Julia constants for nghttp2 error codes

### 1.2 — Session Lifecycle

- [x] `nghttp2_session_callbacks_new()` / `_del()`
- [x] Callback setters (`nghttp2_session_callbacks_set_*`)
- [x] `nghttp2_session_client_new()` / `nghttp2_session_server_new()`
- [x] `nghttp2_session_client_new2()` / `nghttp2_session_server_new2()` (with options)
- [x] `nghttp2_session_del()`
- [x] `nghttp2_option_new()` / `nghttp2_option_del()` and option setters

### 1.3 — Session I/O

- [x] `nghttp2_session_send()` / `nghttp2_session_recv()`
- [x] `nghttp2_session_mem_send()` / `nghttp2_session_mem_recv()`
- [x] `nghttp2_session_want_read()` / `nghttp2_session_want_write()`

### 1.4 — Frame Submission

- [x] `nghttp2_submit_request()` — send HTTP request
- [x] `nghttp2_submit_response()` — send HTTP response
- [x] `nghttp2_submit_headers()` — send HEADERS frame
- [x] `nghttp2_submit_data()` — send DATA frame
- [x] `nghttp2_submit_settings()` — send SETTINGS frame
- [x] `nghttp2_submit_ping()` — send PING frame
- [x] `nghttp2_submit_goaway()` — send GOAWAY frame
- [x] `nghttp2_submit_rst_stream()` — send RST_STREAM frame
- [x] `nghttp2_submit_window_update()` — send WINDOW_UPDATE frame
- [x] `nghttp2_submit_push_promise()` — send PUSH_PROMISE frame

### 1.5 — Stream Management

- [x] `nghttp2_session_find_stream()`
- [x] `nghttp2_session_get_stream_user_data()` / `_set_stream_user_data()`
- [x] `nghttp2_session_get_stream_effective_local_window_size()`
- [x] `nghttp2_session_get_stream_effective_recv_data_length()`

### 1.6 — HPACK (Header Compression)

- [x] `nghttp2_hd_deflate_new()` / `_del()` — create/destroy deflater
- [x] `nghttp2_hd_deflate_hd()` — compress headers
- [x] `nghttp2_hd_inflate_new()` / `_del()` — create/destroy inflater
- [x] `nghttp2_hd_inflate_hd()` — decompress headers

### 1.7 — Validation Utilities

- [x] `nghttp2_check_header_name()` / `nghttp2_check_header_value()`
- [x] `nghttp2_check_authority()`
- [x] `nghttp2_check_path()`
- [x] `nghttp2_check_method()`

---

## Milestone 2 — Julia Type System & Safety Layer

**Goal:** Provide idiomatic Julia types that wrap C pointers with proper resource management.

- [x] Define `Session` type (wraps `nghttp2_session*`) with finalizer
- [x] Define `Callbacks` type (wraps `nghttp2_session_callbacks*`) with finalizer
- [x] Define `Option` type (wraps `nghttp2_option*`) with finalizer
- [x] Define `HpackDeflater` / `HpackInflater` types with finalizers
- [x] Define `NVPair` (name-value pair) helper for HTTP headers
- [x] Define `Frame` types mirroring nghttp2 frame structs
- [x] Implement `show()` methods for all custom types
- [x] Error handling: convert nghttp2 error codes to Julia exceptions (`Nghttp2Error`)

---

## Milestone 3 — High-Level Client API

**Goal:** Provide a user-friendly HTTP/2 client interface.

- [x] `HTTP2Client` type managing connection and session state
- [x] `request(client, method, url; headers, body)` — perform an HTTP/2 request
- [x] Support for `:method`, `:path`, `:scheme`, `:authority` pseudo-headers
- [x] Response type with status, headers, and body
- [x] Streaming response body support
- [x] Connection multiplexing (multiple concurrent streams)
- [x] TLS/ALPN negotiation (integration with MbedTLS.jl or OpenSSL.jl)
- [x] Connection settings configuration (max concurrent streams, window size, etc.)
- [x] Graceful connection shutdown (GOAWAY)

---

## Milestone 4 — High-Level Server API

**Goal:** Provide a user-friendly HTTP/2 server interface.

- [x] `HTTP2Server` type managing listening socket and sessions (h2c + TLS)
- [x] Request handler callback interface
- [ ] Server push support (`PUSH_PROMISE`) — placeholder only, full implementation deferred
- [x] Flow control management (automatic via nghttp2 defaults)
- [x] Concurrent stream handling (task-per-connection)
- [x] Graceful shutdown
- [x] TLS server support with ALPN `h2` (custom non-blocking accept loop working around [OpenSSL.jl upstream bug](upstream-bugs.md))

---

## Milestone 5 — Integration & Ecosystem

**Goal:** Integrate with the Julia HTTP ecosystem and ensure production readiness.

- [ ] Integration with [HTTP.jl](https://github.com/JuliaWeb/HTTP.jl) as an HTTP/2 layer — deferred (requires upstream HTTP.jl changes)
- [x] Interoperability with `Sockets.jl` for transport
- [x] Async I/O support via Julia `Task`s
- [x] Benchmarks (HPACK benchmark suite)
- [x] Comprehensive documentation with examples (multi-page: client, server, low-level, API reference)
- [ ] Register package in the Julia General registry — ready for submission

---

## Milestone 6 — Advanced Features

**Goal:** Support advanced HTTP/2 use cases.

- [x] HPACK standalone API for header compression/decompression
- [x] HTTP/2 proxy support
- [x] WebSocket over HTTP/2 (RFC 8441)
- [x] Connection pooling and keep-alive management
- [x] Priority and dependency tree handling (RFC 7540 §5.3)
- [x] Performance profiling and optimization

---

## Milestone 7 — Incremental server handler (`ServerStream <: IO`)

**Status**: Designed, not implemented.

The buffered handler (`ServerRequest` → `ServerResponse`) delivers the whole
request body before running and takes the whole response body at once. With
trailers it is enough for a unary request/response exchange, but it cannot emit
messages incrementally, so it cannot carry gRPC's three streaming call types.

### Shape

A second entry point passing the handler a stream instead of a request:

```julia
HTTP2Server(8080) do stream
    while !eof(stream)
        chunk = readavailable(stream)
    end
    setstatus(stream, 200)
    setheader(stream, "content-type" => "application/grpc")
    write(stream, payload)
    settrailer(stream, "grpc-status" => "0")
end
```

`ServerStream <: IO`, so it introduces no new vocabulary: `read`, `write`,
`eof`, `readavailable`, `readbytes!`, `isopen`, `close` mean what they already
mean. It mirrors `HTTP.Stream`, which gRPCServer.jl's `AbstractGRPCStream`
contract is already written against — that adapter becomes close to mechanical.

The buffered handler stays as the simple path. The two forms select on handler
arity or an explicit keyword, over one implementation.

### Why `IO` rather than channels

- **No allocation per message.** `readbytes!(stream, buf, n)` fills a
  caller-owned buffer; `Channel{Vector{UInt8}}` forces one allocation per
  message, which is costly on a stream of small gRPC frames.
- **Flow control maps directly.** Incremental writes require the data provider
  to return `NGHTTP2_ERR_DEFERRED` when nothing is available and
  `nghttp2_session_resume_data` once more arrives. That is the semantics of a
  blocking `IO` — no adaptation layer.
- **No task imposed per call.** The handler runs on the connection task.

### Supported `Base` surface — and the trap

Subtyping `IO` inherits a large implicit contract: generic `Base` methods
assume primitives that will not all be implemented, and a partial
implementation fails obscurely.

Two consequences, both deliberate:

- Document exactly which methods are supported, and make the rest fail with a
  clear error rather than falling back to a generic path.
- `Base.read(io, n)` reads *at most* `n` bytes. gRPCServer.jl hit this: a
  single `read(io, len)` returned only what was buffered and capped every
  request at the flow-control window. Any documentation of this type must say
  so, and a `read_exactly`-style helper is worth providing.

Planned surface: `eof`, `isopen`, `close`, `read(::ServerStream, ::Int)`,
`readavailable`, `readbytes!`, `write`, `unsafe_write`, plus `setstatus`,
`setheader`, `settrailer`.

### Write path mechanics

`write` appends to a buffer and calls `nghttp2_session_resume_data`. The data
provider drains that buffer; when it is empty and the handler has not finished,
it returns `NGHTTP2_ERR_DEFERRED` instead of EOF. On completion it sets
`NGHTTP2_DATA_FLAG_EOF`, plus `NGHTTP2_DATA_FLAG_NO_END_STREAM` when trailers
are pending — the mechanism already in place for buffered responses.

## Platform Support

nghttp2_jll provides `libnghttp2` for the following platforms:

| OS      | Architectures                                      |
|---------|-----------------------------------------------------|
| Linux (glibc) | x86_64, i686, aarch64, armv6l, armv7l, powerpc64le, riscv64 |
| Linux (musl)  | x86_64, i686, aarch64, armv6l, armv7l              |
| macOS         | x86_64, aarch64 (Apple Silicon)                    |
| FreeBSD       | x86_64, aarch64                                    |
| Windows       | x86_64, i686                                       |

---

## References

- [nghttp2 — HTTP/2 C Library](https://nghttp2.org/)
- [nghttp2 C API documentation](https://nghttp2.org/documentation/)
- [nghttp2_jll.jl](https://github.com/JuliaBinaryWrappers/nghttp2_jll.jl)
- [nghttp2_jll registration (General#150873)](https://github.com/JuliaRegistries/General/pull/150873)
- [RFC 7540 — HTTP/2](https://httpwg.org/specs/rfc7540.html)
- [RFC 7541 — HPACK](https://httpwg.org/specs/rfc7541.html)
