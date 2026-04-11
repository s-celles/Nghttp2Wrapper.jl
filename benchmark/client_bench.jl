using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(PackageSpec(path=dirname(@__DIR__)))
Pkg.instantiate()

using BenchmarkTools
using Nghttp2Wrapper

println("=== Nghttp2Wrapper.jl Client Benchmarks ===")
println()

# HPACK benchmarks (no network)
println("--- HPACK Benchmarks ---")
headers = [NVPair(":method", "GET"), NVPair(":path", "/")]

d = HpackDeflater()
b_deflate = @benchmark deflate($d, $headers)
println("Deflate (2 headers): ", median(b_deflate))
close(d)

d2 = HpackDeflater()
i = HpackInflater()
compressed = deflate(d2, headers)
b_inflate = @benchmark inflate($i, $compressed)
println("Inflate (2 headers): ", median(b_inflate))
close(d2)
close(i)

println()
println("--- Network Benchmarks (nghttp2.org) ---")
client = HTTP2Client("nghttp2.org")

b_get = @benchmark get($client, "/") samples=5 evals=1
println("Single GET: ", median(b_get))

close(client)
println()
println("Done!")
