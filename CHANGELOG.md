# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`ServerStream <: IO`**, the incremental handler surface (ROADMAP
  Milestone 7). Subtypes `IO`, so a handler needs no new vocabulary: `read`,
  `readavailable`, `readbytes!`, `eof`, `write`, `isopen` and `close` mean what
  they already mean, alongside `setstatus`, `setheader` and `settrailer`.

  Chosen over a channel-based API because `readbytes!` fills a caller-owned
  buffer — no allocation per message — and because blocking `IO` semantics are
  exactly what nghttp2's deferred data provider needs.

  Two behaviours worth knowing, both pinned by tests:

  - `eof` **blocks** while the peer may still send. That is deliberate, and it
    is what makes the deferred provider work, but it means `eof` is not a
    "is anything available right now" probe.
  - `read(stream, n)` returns *at most* `n` bytes, as for any `IO`. A short
    read is neither an error nor end-of-stream.

  The type is complete and tested in isolation; wiring it into `HTTP2Server` so
  a handler can be driven by it is the next step and is not yet done.
- **`ServerResponse` can carry trailers.** `ServerResponse(status, body;
  trailers = [...])` emits them as a HEADERS block after the body. The last
  DATA frame is flagged `NGHTTP2_DATA_FLAG_NO_END_STREAM` so the body no
  longer closes the stream — the trailers do.

  This is what makes trailers reachable from `HTTP2Server`: the binding alone
  was only usable by driving a session through the low-level API. A gRPC
  *unary* response is now expressible.

  A trailers-only response (empty body) still goes through a data provider: a
  `C_NULL` provider makes nghttp2 put END_STREAM on the HEADERS frame, leaving
  no point at which trailers could follow.

  The three-positional-argument `ServerResponse(status, headers, body)` form is
  kept, so existing callers are unaffected.
- **`nghttp2_submit_trailer`**, with a pointer-level entry point and an
  `NVPair` convenience overload. A trailing HEADERS block is sent after the
  response body and closes the stream (RFC 7540 §8.1).

  This was a hard blocker for anything speaking gRPC on top of this package:
  a gRPC response carries its status in the trailers, not in the response
  headers, so no call could complete without it. Requested by gRPCServer.jl,
  which is evaluating an `nghttp2` backend.

  Documented return values are measured, not assumed: `stream_id` is validated
  eagerly (0 gives `NGHTTP2_ERR_INVALID_ARGUMENT`, -501), while the existence
  of the stream is only checked at send time.

## [0.2.0] — 2026-04-13

### Changed

- **TLS backend migrated from OpenSSL.jl to [Reseau.jl](https://github.com/JuliaServices/Reseau.jl).** Both `HTTP2Client` and `HTTP2Server` now use Reseau's `TLS.connect` / `TLS.listen` / `TLS.accept`. The public API (`HTTP2Client`, `HTTP2Server`, their constructors, keyword arguments, and request/response types) is unchanged.
- Internal `HTTP2Server.ssl_ctx` field renamed to `tls_config` (now holds a `Reseau.TLS.Config`).
- `HTTP2Client` now verifies `alpn_protocol == "h2"` via `Reseau.TLS.connection_state` and raises a clear error if the peer did not negotiate `h2`.

### Added

- Internal helper `Nghttp2Wrapper.listener_port(server)` that returns the bound port for both plaintext and TLS listeners.

### Removed

- `OpenSSL` runtime dependency.
- Bespoke `_ssl_server_accept` handshake-retry workaround in `src/server.jl` (the ccalls into `SSL_accept` and `SSL_get_error` are gone — Reseau's `TLS.accept` drives the handshake to completion internally).
- Internal `HTTP2Client.tcp_socket` field (the TLS connection now owns the underlying TCP socket).

### Fixed

- Server-side TLS accept no longer carries a workaround for the upstream OpenSSL.jl `SSL_accept` single-shot bug. See `upstream-bugs.md` for historical context.

## [0.1.0]

### Added

- Initial project bootstrap: package structure, module, tests, documentation, CI
- Dependency on `nghttp2_jll` for HTTP/2 C library bindings
- Test infrastructure using TestItemRunner.jl
- Documentation setup using Documenter.jl
- GitHub Actions CI for Linux, macOS, and Windows
- Low-level C bindings for nghttp2 via `ccall` (Milestone 1):
  - Version info and error handling (`nghttp2_version`, `nghttp2_strerror`, `nghttp2_is_fatal`)
  - Error code constants (`NGHTTP2_ERR_*`) and NV flag constants
  - Session lifecycle management (client/server create, destroy, options)
  - Callback object management with all setter functions
  - Session I/O (`nghttp2_session_mem_send2`, `nghttp2_session_mem_recv2`, want_read/write)
  - Frame submission (request, response, headers, settings, ping, goaway, rst_stream, window_update, push_promise)
  - Stream management (find, get/set user data, window sizes)
  - HPACK header compression/decompression (deflate/inflate)
  - Validation utilities (header name/value, authority, path, method)
- Julia type system and safety layer (Milestone 2):
  - `Nghttp2Error` exception type with error code, message, and fatal flag
  - `NVPair` type for ergonomic HTTP header construction from Julia strings
  - `Session` wrapper with automatic resource cleanup via finalizer
  - `Callbacks` wrapper with finalizer and GC-safe closure storage
  - `Option` wrapper with finalizer and convenience setter methods
  - `HpackDeflater` and `HpackInflater` wrappers with finalizers
  - Typed session operations: `submit_settings!`, `send!`, `recv!`, `want_read`, `want_write`, `submit_ping!`, `submit_goaway!`
  - High-level `deflate` and `inflate` functions for HPACK
  - `show()` methods for all wrapper types
  - Idempotent `close()` with use-after-close detection on all wrapper types
- High-level HTTP/2 client API (Milestone 3):
  - `HTTP2Client` type with automatic TLS/ALPN connection to HTTPS servers
  - `Request` and `Response` types for HTTP/2 request/response representation
  - `request()` function with automatic pseudo-header construction
  - Convenience methods: `get`, `post`, `put`, `delete`, `patch`, `head`, `options`
  - Connection multiplexing with concurrent stream tracking
  - `request_stream()` for streaming response body via Channel
  - Configurable connection settings (max concurrent streams, window size, header table size)
  - `shutdown!()` for graceful connection shutdown via GOAWAY
  - Dependencies: OpenSSL.jl (TLS), URIs.jl (URL parsing), Sockets (stdlib)
- High-level HTTP/2 server API (Milestone 4):
  - `HTTP2Server` type with request handler callback interface
  - `ServerRequest` and `ServerResponse` types for server-side request/response
  - Cleartext HTTP/2 (h2c) support
  - TLS server support with ALPN `h2` (via custom non-blocking accept loop working around OpenSSL.jl upstream bug)
  - Concurrent connection handling via task-per-connection model
  - Handler exception safety: errors → 500 response without server crash
  - Graceful shutdown via `shutdown!()`
  - Documented OpenSSL.jl server-side TLS accept bug in upstream-bugs.md
- Integration and ecosystem readiness (Milestone 5):
  - Multi-page documentation: Client Guide, Server Guide, Low-Level API, API Reference, Benchmarks
  - Async I/O verification: concurrent Tasks with separate and shared clients
  - HPACK benchmark suite (benchmark/ directory)
  - IO interoperability: Session API works with any Julia IO stream
  - Known limitations documented (TLS server, request body streaming)
- Advanced HTTP/2 features (Milestone 6):
  - `ConnectionPool` type with automatic connection reuse, idle timeout, and max-per-host limits
  - `pool_get`, `pool_post`, `pool_request` convenience methods with URL parsing
  - `PrioritySpec` type for HTTP/2 stream priority configuration
  - `forward_request` proxy helper for forwarding between server and client sessions
  - `websocket_connect` for WebSocket over HTTP/2 (RFC 8441) CONNECT framing
  - HPACK dynamic table inspection: `inspect_dynamic_table`, `dynamic_table_size`
  - Performance allocation baselines documented
