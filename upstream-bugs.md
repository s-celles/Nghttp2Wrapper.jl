# Upstream Issues

## OpenSSL.jl — Server-side TLS accept doesn't handle non-blocking BIO

**Package**: [OpenSSL.jl](https://github.com/JuliaWeb/OpenSSL.jl) v1.6.1
**Discovered**: 2026-04-11
**Status**: **Resolved for Nghttp2Wrapper.jl 2026-04-13 by feature 008-reseau-tls-migration** — the package no longer depends on OpenSSL.jl. Server-side TLS accept is now handled by [Reseau.jl](https://github.com/JuliaServices/Reseau.jl)'s `TLS.accept`, which drives the handshake to completion internally. The OpenSSL.jl upstream bug may still exist for other downstream consumers; this entry is retained for historical context.
**Impact**: Was blocking HTTP/2 server TLS support (Milestone 4)

**Resolution in Nghttp2Wrapper.jl**: We implemented a custom
`_ssl_server_accept` function (in `src/server.jl`) that wraps
`SSL_accept` in a retry loop handling `SSL_ERROR_WANT_READ` by waiting
on `eof(tcp)` of the underlying raw TCP socket. Combined with running
the accept loop on a separate OS thread via `Threads.@spawn`, this
avoids the deadlock that occurs when trying to do TLS handshake in the
main task's cooperative scheduler.

### Description

OpenSSL.jl's `Sockets.accept(ssl::SSLStream)` calls `ssl_accept(ssl.ssl)` which
directly calls `SSL_accept()`. Unlike the client-side `connect()` function which
has a retry loop handling `SSL_ERROR_WANT_READ/WRITE`, the server-side `accept()`
does not handle these cases.

When the underlying BIO is non-blocking (Julia's TCPSocket wrapped in BIO),
`SSL_accept()` returns -1 with `SSL_ERROR_WANT_READ` because the TLS handshake
requires reading data from the client. The function then throws
`OpenSSLError("error:FFFFFFFFFFFFFFFF:system library::reason(2139357183)")`.

### Root Cause

Compare in `ssl.jl`:
- **Client `connect()`** (line 509): Has a `while true` loop with
  `SSL_ERROR_WANT_READ` handling and `eof(ssl.io)` wait
- **Server `accept()`** (line 576): Single call to `ssl_accept()` with
  no retry loop, no `SSL_ERROR_WANT_READ` handling

### Workaround Attempted

Implementing a custom accept loop following the `connect()` pattern:
```julia
function _ssl_server_accept(tls_stream)
    ssl = tls_stream.ssl
    while true
        ret = ccall((:SSL_accept, libssl), Cint, (SSL,), ssl)
        if ret == 1; return; end
        err = ccall((:SSL_get_error, libssl), Cint, (SSL, Cint), ssl, ret)
        if err == SSL_ERROR_WANT_READ
            eof(tls_stream.io) && throw(EOFError())
        else
            throw(OpenSSLError("SSL_accept failed"))
        end
    end
end
```

This workaround deadlocks when server and client run in the same process
(Julia's cooperative scheduling prevents interleaving I/O), and also deadlocks
across threads. The fundamental issue appears to be that the BIO layer's
blocking read on `eof(tls_stream.io)` prevents the Julia event loop from
servicing the client-side writes.

### Impact on Nghttp2Wrapper.jl

- Milestone 4 (HTTP/2 Server) cannot support TLS via OpenSSL.jl
- Server tests cannot use HTTP2Client for end-to-end testing in-process
- Alternative: Use cleartext HTTP/2 (h2c) for initial server implementation,
  add TLS via MbedTLS.jl or wait for OpenSSL.jl fix

### Possible Fixes

1. **Upstream fix**: OpenSSL.jl should add a proper handshake loop to
   `Sockets.accept(ssl::SSLStream)` matching the `connect()` pattern
2. **Alternative TLS**: Use MbedTLS.jl for server-side TLS (HTTP.jl's server
   still uses MbedTLS for this reason)
3. **Separate process**: Run server in a separate Julia process for testing
