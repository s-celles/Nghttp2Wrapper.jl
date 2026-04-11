@testitem "Request construction" begin
    using Nghttp2Wrapper
    r = Request("GET", "/path")
    @test r.method == "GET"
    @test r.path == "/path"
    @test isempty(r.headers)
    @test isempty(r.body)
end

@testitem "Request with headers and body" begin
    using Nghttp2Wrapper
    headers = [NVPair("content-type", "application/json")]
    body = Vector{UInt8}("{\"key\":\"value\"}")
    r = Request("POST", "/api"; headers=headers, body=body)
    @test r.method == "POST"
    @test r.path == "/api"
    @test length(r.headers) == 1
    @test !isempty(r.body)
end

@testitem "Request show" begin
    using Nghttp2Wrapper
    r = Request("GET", "/")
    s = sprint(show, r)
    @test occursin("GET", s)
    @test occursin("/", s)
    @test occursin("Request", s)
end
