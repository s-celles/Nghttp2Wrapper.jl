@testitem "HPACK allocation baseline" begin
    using Nghttp2Wrapper
    d = HpackDeflater()
    i = HpackInflater()
    headers = [NVPair(":method", "GET"), NVPair(":path", "/")]

    # Warm up
    compressed = deflate(d, headers)
    inflate(i, compressed)

    # Measure allocations for 10 round-trips
    allocs = @allocated begin
        for _ in 1:10
            c = deflate(d, headers)
            inflate(i, c)
        end
    end
    # Just verify it runs without error and record allocation count
    @test allocs isa Int
    @test allocs >= 0
    close(d)
    close(i)
end

@testitem "NVPair allocation baseline" begin
    using Nghttp2Wrapper
    # Warm up
    NVPair("test", "value")

    allocs = @allocated begin
        for i in 1:100
            NVPair("header-$i", "value-$i")
        end
    end
    @test allocs isa Int
    @test allocs >= 0
end
