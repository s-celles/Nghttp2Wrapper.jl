# Nghttp2Wrapper.jl

[![CI](https://github.com/s-celles/Nghttp2Wrapper.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/s-celles/Nghttp2Wrapper.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://s-celles.github.io/Nghttp2Wrapper.jl/dev/)

A Julia wrapper for the [nghttp2](https://nghttp2.org/) HTTP/2 C library, using [`nghttp2_jll`](https://github.com/JuliaBinaryWrappers/nghttp2_jll.jl).

## Overview

Nghttp2Wrapper.jl provides Julia bindings to nghttp2, an implementation of HTTP/2 and its header compression algorithm HPACK (RFC 7540, RFC 7541).

## Installation

```julia
using Pkg
Pkg.add("Nghttp2Wrapper")
```

## Usage

```julia
using Nghttp2Wrapper
```

## License

MIT License. See [LICENSE](LICENSE) for details.
