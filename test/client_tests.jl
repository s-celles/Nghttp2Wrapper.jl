@testitem "HTTP2Client connect" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    @test isopen(client) == true
    close(client)
    @test isopen(client) == false
end

@testitem "TLS ALPN negotiation" begin
    using Nghttp2Wrapper
    # If we get here without error, ALPN negotiated h2 successfully
    client = HTTP2Client("nghttp2.org")
    @test isopen(client)
    close(client)
end

@testitem "custom settings" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org"; max_concurrent_streams=50)
    @test isopen(client)
    close(client)
end

@testitem "default settings" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    @test isopen(client)
    close(client)
end

@testitem "HTTP2Client show" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    s = sprint(show, client)
    @test occursin("nghttp2.org", s)
    @test occursin("open", s)
    close(client)
end

@testitem "graceful shutdown" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    shutdown!(client)
    @test !isopen(client)
end
