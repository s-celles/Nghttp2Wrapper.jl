@testitem "HpackDeflater lifecycle" begin
    using Nghttp2Wrapper
    d = HpackDeflater()
    @test isopen(d) == true
    close(d)
    @test isopen(d) == false
    close(d)  # idempotent
end

@testitem "HpackInflater lifecycle" begin
    using Nghttp2Wrapper
    i = HpackInflater()
    @test isopen(i) == true
    close(i)
    @test isopen(i) == false
    close(i)  # idempotent
end

@testitem "HpackDeflater show" begin
    using Nghttp2Wrapper
    d = HpackDeflater()
    s = sprint(show, d)
    @test occursin("HpackDeflater", s)
    @test occursin("4096", s)
    close(d)
end

@testitem "HPACK deflate typed" begin
    using Nghttp2Wrapper
    d = HpackDeflater()
    headers = [NVPair(":method", "GET"), NVPair(":path", "/")]
    compressed = deflate(d, headers)
    @test compressed isa Vector{UInt8}
    @test length(compressed) > 0
    close(d)
end

@testitem "HPACK round-trip typed" begin
    using Nghttp2Wrapper
    d = HpackDeflater()
    i = HpackInflater()

    headers = [NVPair(":method", "GET"), NVPair(":path", "/")]
    compressed = deflate(d, headers)
    recovered = inflate(i, compressed)

    @test length(recovered) == 2
    @test recovered[1].name == Vector{UInt8}(":method")
    @test recovered[1].value == Vector{UInt8}("GET")
    @test recovered[2].name == Vector{UInt8}(":path")
    @test recovered[2].value == Vector{UInt8}("/")

    close(d)
    close(i)
end
