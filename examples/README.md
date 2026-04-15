# Nghttp2Wrapper.jl — Examples

Runnable example scripts for Nghttp2Wrapper.jl. Each script is self-contained
and expects to be run from the repository root with the package environment
activated:

```sh
julia --project=. examples/<script>.jl
```

## Available examples

| Script | Description |
|--------|-------------|
| [`browser_hello.jl`](browser_hello.jl) | Minimal HTTP/2 "hello world" server over TLS, reachable from any browser at `https://localhost:8443`. |

## Browsers and HTTP/2

All major browsers require HTTP/2 to be negotiated over TLS via ALPN. They do
**not** support h2c (plaintext HTTP/2), so a cleartext `HTTP2Server(8080)` is
only reachable from clients such as `curl --http2-prior-knowledge` or
`Nghttp2Wrapper`'s own `HTTP2Client`. To test from a browser, use the TLS
example above — it reuses the self-signed test certificate from
`test/fixtures/`, which is suitable for local experimentation only.
