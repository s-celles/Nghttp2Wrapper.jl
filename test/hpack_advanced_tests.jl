@testitem "inspect dynamic table" begin
    using Nghttp2Wrapper
    d = HpackDeflater()
    # Compress some headers to populate dynamic table
    headers = [NVPair(":method", "GET"), NVPair(":path", "/test")]
    deflate(d, headers)
    # Inspect (returns empty — nghttp2 doesn't expose iteration)
    table = inspect_dynamic_table(d)
    @test table isa Vector{NVPair}
    close(d)
end

@testitem "dynamic table size" begin
    using Nghttp2Wrapper
    d = HpackDeflater(8192)
    @test dynamic_table_size(d) == 8192
    d2 = HpackDeflater()
    @test dynamic_table_size(d2) == 4096
    close(d)
    close(d2)
end

@testitem "HPACK deterministic compression" begin
    using Nghttp2Wrapper
    # Two deflaters with same input should produce same output
    d1 = HpackDeflater()
    d2 = HpackDeflater()
    headers = [NVPair(":method", "GET"), NVPair(":path", "/")]
    c1 = deflate(d1, headers)
    c2 = deflate(d2, headers)
    @test c1 == c2
    close(d1)
    close(d2)
end
