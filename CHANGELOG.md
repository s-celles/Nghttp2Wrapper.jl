# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Mutual TLS on the server** (ROADMAP Milestone 8.3). `HTTP2Server` accepted a
  certificate and a key and nothing else, so `client_ca`, `require_client_cert`
  and `min_tls_version` had nowhere to be expressed — and in gRPCServer.jl they
  were silently discarded, which meant one could configure mTLS and get a server
  that never verified a client certificate.

  These options are **refused, not ignored**, on a plaintext listener, and
  `require_client_cert` without a `client_ca` is refused too: there would be
  nothing to verify against.

  Fixtures are generated on demand by `test/fixtures/generate_mtls_certs.jl`,
  called from `runtests.jl`, and are not committed — private keys do not belong
  in a repository. The generator *raises* when `openssl` is absent rather than
  returning quietly, because a silent return is how a whole test surface
  disappears while CI stays green.



- **Server SETTINGS are configurable** (ROADMAP Milestone 8.1). `HTTP2Server`
  submitted an empty SETTINGS frame on every connection, so every server ran on
  protocol defaults and could not bound concurrent streams or adjust its window,
  frame or header-list limits — a caller's configuration was simply dropped.

  ```julia
  HTTP2Server(8080; max_concurrent_streams = 100, initial_window_size = 1 << 20)
  ```

  Named keywords rather than a `Vector{Nghttp2SettingsEntry}`: these four are
  what a server realistically sets, and the entry form is ceremony for them.
  Anything else remains reachable through the exported
  `nghttp2_submit_settings`. A setting left unset is **not sent**, so the
  default is unchanged and no existing server's protocol behaviour moves.
- **`peer_address`** (ROADMAP Milestone 8.2), on both `ServerRequest` and
  `ServerStream`. A handler could not tell who was calling, which ruled out
  per-client rate limiting, audit logging and address-based access control, and
  forced gRPCServer.jl's adapter to present a fabricated zero as fact.

  Returns a `Sockets.InetAddr`, or `nothing` when the endpoint cannot be
  resolved, so a caller can tell "unknown" from an address. Works for both
  listener kinds — Reseau caches it on TLS connections, plain sockets answer
  `getpeername`.

  `ServerRequest` gains a field; its five-argument constructor is kept, so
  existing callers are unaffected.



- **Incremental server handlers** (ROADMAP Milestone 7). `HTTP2Server(port;
  streaming = true)` hands the handler a `ServerStream` instead of a complete
  `ServerRequest`, so a response is emitted as it is produced rather than
  assembled and returned at the end.

  ```julia
  HTTP2Server(8080; streaming = true) do stream
      setstatus(stream, 200)
      for i in 1:5
          write(stream, Vector{UInt8}("event $i\n"))
          sleep(1)
      end
  end
  ```

  This is what the three streaming call types need — server streaming and
  bidirectional exchanges were impossible with a buffered handler, since the
  reply only reached the peer once the handler returned.

  `ServerStream` subtypes `IO`, so `eof`, `read`, `readavailable` and
  `readbytes!` keep their usual meaning, and the request head is reachable
  through the new `request_method`, `request_path` and `request_headers`.

  The buffered handler remains the **default** and is unchanged. Selection is a
  keyword rather than handler arity, because a `do` block is one-argument in
  both forms.

  Status and headers must be staged before the first `write`: the response is
  submitted on that write, so afterwards the headers are already on the wire.

  `close(server)` now waits for incremental handlers in flight as it does for
  buffered ones. They run in their own tasks, so the flag the read loop
  maintains says nothing about them, and without this they would be cut off the
  moment `close` was called however generous its timeout.
- **`nghttp2_session_resume_data`** — un-defers a stream's data provider. A
  provider with nothing to send returns `NGHTTP2_ERR_DEFERRED` rather than
  end-of-data, and this is what tells nghttp2 to ask again; without it an
  incremental handler's later writes are never collected.

### Fixed

- **No certificates or private keys in the repository.** `test/fixtures/`
  carried a committed `server.crt` and `server.key`, and `.gitignore` allowed
  any `*.crt` or `*.key` beside them — while its own comment said "script but
  not generated certs".

  All of it is generated now, by `test/fixtures/generate_mtls_certs.jl`, which
  `runtests.jl` calls before anything runs and `examples/browser_hello.jl` calls
  for itself. The ignore rule is absolute: "these keys are fine, those are not"
  is a distinction that erodes, and one `git add -A` is all it takes.

  The regenerated server certificate also carries a `subjectAltName`, which the
  committed one lacked — a certificate identified only by its CN is rejected
  outright by anything modern.

  Removing the files does not erase them from history. They are throwaway
  development keys for `localhost` with no value, so they are left there rather
  than rewriting history over them.

- **The `Reseau = "1"` bound is now actually tested.** A new `downgrade` CI job
  resolves the oldest versions every `[compat]` bound allows and runs the suite
  against them.

  Without it the bounds were a claim nobody checked: CI only ever saw Reseau
  1.3.4, while the bound admits 1.0.1. A local checkout sitting on 1.0.1 failed
  on `TLS.connect(network, address, config)` — an API the package does not use
  but a new test did. The bound was truthful and the suite was not portable to
  it, which is just as invisible as an untruthful bound. The test now uses the
  keyword form, which spans the whole 1.x range; verified green on both 1.0.1
  and 1.3.4.



- **A forced `close` no longer waits for a busy handler.** `close(server;
  timeout = 0)` took exactly as long as the slowest running handler — the
  opposite of what asking for zero grace means.

  The cause was in the GOAWAY step, added alongside bounded shutdown in 0.3.0.
  Sending GOAWAY needs the connection's lock, and the connection task holds that
  lock across its whole receive/handle/send block — so a handler mid-flight
  holds it for as long as it runs, and `close` blocked there before it ever
  reached the socket close that actually bounds shutdown.

  The wait for that lock is now bounded at 0.25s. A connection that cannot be
  reached in time is skipped and retried after the graceful phase, once it is
  idle, so the courtesy is still paid whenever there is any opportunity to pay
  it. GOAWAY is a courtesy; the socket close that follows is not.

  Found from downstream: gRPCServer.jl's nghttp2 adapter maps its `force` flag
  onto `timeout = 0`, and a test asserting that a forced stop does not wait out
  a four-second handler measured 4.21s.

- **The `concurrent connections` test was measuring itself, not the server.** It
  counted handler calls in a `Ref` incremented from three handler tasks, and
  `count[] += 1` is a load, an add and a store — concurrent increments were
  lost. It also serialised its clients, each closing its connection 0.5s after
  writing and before the next connected, so the server was never actually asked
  to hold three connections at once.

  Rewritten to open all three connections, send all three requests, and only
  then close anything, with an atomic counter. Verified against unmodified
  `main`: with three simultaneous connections and the old `Ref`, the test
  reports `1 >= 3` every time while the server has in fact served all three.

## [0.3.0] — 2026-07-31

### Changed

- **`close(server)` is bounded, and no longer waits indefinitely.** This is why
  the release is 0.3.0 and not a patch: shutdown had an observable behaviour,
  and it changed.

  A handler that runs longer than the grace period now has its connection closed
  underneath it, where previously `close` would keep waiting. Pass a longer
  `timeout` if your handlers are slow:

      close(server)                 # 5 s grace, the default
      close(server; timeout = 30)   # long-running handlers
      close(server; timeout = 0)    # immediate

  In practice the old behaviour was rarely something to rely on — see below.

### Fixed

- **`close(server)` is now bounded and tells the peer.** It used to close the
  listener and then `wait` on every connection task with no bound. A connection
  task spends its life blocked reading from its peer, and an idle peer sends
  nothing — so `close` could not return: the loop condition
  `while server.isopen && isopen(io)` is only re-tested once the read returns.
  A single connected, silent client was enough to hang shutdown forever.

  Shutdown now runs in three phases. The listener closes. Every live session is
  sent a **GOAWAY** (RFC 7540 §6.8) carrying the last stream it actually
  processed — via the new `nghttp2_session_get_last_proc_stream_id` binding — so
  a peer knows precisely which requests are safe to retry elsewhere. In-flight
  requests then get up to `timeout` seconds, after which the remaining sockets
  are closed regardless, which is what makes the reads return.

      close(server)                 # 5 s grace, the default
      close(server; timeout = 30)   # long-running handlers
      close(server; timeout = 0)    # immediate

  `shutdown!` was a copy of the same unbounded loop and is now an alias for
  `close`, keyword included.

  Two implementation notes, both load-bearing:

  - An nghttp2 session is **not thread-safe**, and `close` now reaches into one
    from a task that is not the connection's. Every call into a session is
    serialised on `ServerContext.lock`; the blocking read stays outside it.
  - `ServerContext.session_ptr` is set to `C_NULL` under that same lock
    *before* `nghttp2_session_del`, so a concurrent `close` either wins the lock
    and finds a live session or finds the null and skips it. Without that
    ordering the GOAWAY path is a use-after-free.

  Waiting on in-flight work needed a new signal rather than the existing stream
  table: a stream is deleted from `ServerContext.streams` *before* its handler
  runs, so the table is empty for exactly the window that matters.

### Added

- **`nghttp2_session_get_last_proc_stream_id`** — the ID of the last stream a
  session finished processing. This is the value a GOAWAY frame should carry.

## [0.2.1] — 2026-07-30

### Fixed

- **`Sockets` compat relaxed from `"1.11"` to `"1"`.** Sockets is a standard
  library, so that bound imposed a Julia floor of its own, unrelated to anything
  this package needs — and it was the first constraint an attempt to support the
  1.10 LTS hit, masking the real one behind it.

  The real floor is unchanged and stays `julia = "1.12"`: this package calls
  nghttp2's `size_t` API (`mem_recv2`, `mem_send2`, `submit_request2`,
  `submit_response2`, `hd_*_hd2`, the `_callback2` setters), introduced in
  nghttp2 1.57.0, and `nghttp2_jll` is itself a standard library — Julia 1.10
  ships 1.52.0. ROADMAP.md now records this, since nothing in the Julia source
  reveals it.

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
