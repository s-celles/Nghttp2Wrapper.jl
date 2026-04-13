# Security Policy

## Supported Versions

Only the latest released minor version of Nghttp2Wrapper.jl receives security
fixes. As the project is pre-1.0, earlier minor releases are not supported.

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, report them privately by emailing **s.celles@gmail.com** with the
subject line `[Nghttp2Wrapper.jl security]`. Include:

- A description of the issue and its potential impact
- Steps to reproduce (minimal example preferred)
- The version of Nghttp2Wrapper.jl, Julia, and any relevant dependencies
  (`nghttp2_jll`, `Reseau`) you tested against
- Whether you would like to be credited in the fix's changelog entry

You should receive an initial acknowledgement within 7 days. Once the issue
is confirmed, a fix will be prepared, released on the Julia General registry,
and described in `CHANGELOG.md` under the corresponding version.

## Scope

Nghttp2Wrapper.jl is a thin Julia wrapper over the [nghttp2](https://nghttp2.org)
C library (via [`nghttp2_jll`](https://github.com/JuliaBinaryWrappers/nghttp2_jll.jl))
and the [Reseau.jl](https://github.com/JuliaServices/Reseau.jl) TLS stack.
Issues rooted in those upstream projects should be reported to them directly;
this policy covers defects in the Julia wrapper layer itself (ccall safety,
memory management of C resources, HTTP/2 framing, HPACK, stream lifecycle,
server-side request handling, and TLS configuration defaults).
