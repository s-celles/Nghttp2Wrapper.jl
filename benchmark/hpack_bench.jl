using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(PackageSpec(path=dirname(@__DIR__)))
Pkg.instantiate()

using BenchmarkTools
using Nghttp2Wrapper

println("=== HPACK Benchmarks ===")
println()

for n in [1, 5, 10, 50]
    headers = [NVPair("header-$i", "value-$i") for i in 1:n]

    d = HpackDeflater()
    i = HpackInflater()

    b_deflate = @benchmark deflate($d, $headers)
    compressed = deflate(d, headers)
    b_inflate = @benchmark inflate($i, $compressed)

    println("$n headers:")
    println("  Deflate: ", median(b_deflate))
    println("  Inflate: ", median(b_inflate))
    println("  Compressed size: $(length(compressed)) bytes")
    println()

    close(d)
    close(i)
end

println("Done!")
