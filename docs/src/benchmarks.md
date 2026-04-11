# Benchmarks

Performance benchmarks for Nghttp2Wrapper.jl.

## Methodology

Benchmarks are run using [BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl). Network benchmarks connect to `nghttp2.org` over HTTPS.

To reproduce, run from the repository root:

```bash
julia --project=benchmark benchmark/client_bench.jl
julia --project=benchmark benchmark/hpack_bench.jl
```

## HPACK Performance

Header compression/decompression throughput using the standalone HPACK API.

| Operation | Headers | Time (median) | Allocations |
|-----------|---------|---------------|-------------|
| Deflate | 2 headers | ~5 us | ~10 |
| Inflate | 2 headers | ~3 us | ~8 |
| Round-trip | 2 headers | ~8 us | ~18 |

*Results are approximate and depend on hardware. Run the benchmark suite for your system.*

## Client Performance

Network request throughput (dependent on network latency to nghttp2.org).

| Operation | Description | Time (median) |
|-----------|-------------|---------------|
| Single GET | One request to nghttp2.org | ~100-300 ms |
| 5 concurrent GETs | Multiplexed on one connection | ~150-400 ms |

*Network benchmarks are highly dependent on network conditions and server load.*

## System Information

Report your system info when sharing results:

```julia
using InteractiveUtils
versioninfo()
```
