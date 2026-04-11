@testitem "concurrent requests" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    tasks = [@async get(client, "/") for _ in 1:3]
    responses = [fetch(t) for t in tasks]
    @test all(r -> r.status == 200, responses)
    @test all(r -> !isempty(r.body), responses)
    close(client)
end
