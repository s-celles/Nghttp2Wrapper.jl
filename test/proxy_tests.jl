@testitem "forward_request" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    # Create a mock ServerRequest
    req = ServerRequest("GET", "/", NVPair[], UInt8[], Int32(1))
    resp = forward_request(client, req)
    @test resp.status == 200
    @test resp isa ServerResponse
    @test !isempty(resp.body)
    close(client)
end
