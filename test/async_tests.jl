@testitem "multiple tasks separate clients" begin
    using Nghttp2Wrapper
    tasks = [@async begin
        client = HTTP2Client("nghttp2.org")
        resp = get(client, "/")
        close(client)
        resp
    end for _ in 1:3]
    responses = [fetch(t) for t in tasks]
    @test all(r -> r.status == 200, responses)
end

@testitem "multiple tasks same client" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    tasks = [@async get(client, "/") for _ in 1:3]
    responses = [fetch(t) for t in tasks]
    @test all(r -> r.status == 200, responses)
    close(client)
end
