@testitem "Response construction" begin
    using Nghttp2Wrapper
    headers = [NVPair("content-type", "text/html")]
    body = Vector{UInt8}("<html></html>")
    r = Response(200, headers, body)
    @test r.status == 200
    @test length(r.headers) == 1
    @test !isempty(r.body)
end

@testitem "Response show" begin
    using Nghttp2Wrapper
    r = Response(200, NVPair[], UInt8[1,2,3])
    s = sprint(show, r)
    @test occursin("200", s)
    @test occursin("3 bytes", s)
end
