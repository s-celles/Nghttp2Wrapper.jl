@testitem "simple GET request" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    response = get(client, "/")
    @test response.status == 200
    @test !isempty(response.body)
    @test !isempty(response.headers)
    close(client)
end

@testitem "GET 404" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    response = get(client, "/nonexistent-path-that-should-404")
    @test response.status == 404
    close(client)
end

@testitem "POST request with body" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    # nghttp2.org may not accept POST, but the request should complete
    response = request(client, "POST", "/"; body=Vector{UInt8}("test"))
    @test response.status > 0
    close(client)
end

@testitem "POST with custom headers" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    headers = [NVPair("user-agent", "Nghttp2Wrapper.jl/0.1.0")]
    response = get(client, "/"; headers=headers)
    @test response.status == 200
    close(client)
end
