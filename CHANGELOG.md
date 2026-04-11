# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
  - Cleartext HTTP/2 (h2c) support — TLS server deferred pending OpenSSL.jl upstream fix
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
