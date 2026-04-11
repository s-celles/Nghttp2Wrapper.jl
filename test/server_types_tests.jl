@testitem "ServerRequest construction" begin
    using Nghttp2Wrapper
    req = ServerRequest("GET", "/", NVPair[], UInt8[], Int32(1))
    @test req.method == "GET"
    @test req.path == "/"
    @test isempty(req.headers)
    @test isempty(req.body)
    @test req.stream_id == Int32(1)
end

@testitem "ServerResponse construction" begin
    using Nghttp2Wrapper
    resp = ServerResponse(200; body=Vector{UInt8}("Hello"))
    @test resp.status == 200
    @test resp.body == Vector{UInt8}("Hello")
    @test isempty(resp.headers)
end

@testitem "ServerResponse from string" begin
    using Nghttp2Wrapper
    resp = ServerResponse(200, "Hello")
    @test resp.status == 200
    @test resp.body == Vector{UInt8}("Hello")
end

@testitem "ServerResponse show" begin
    using Nghttp2Wrapper
    resp = ServerResponse(200, "Hello")
    s = sprint(show, resp)
    @test occursin("200", s)
    @test occursin("5 bytes", s)
end
