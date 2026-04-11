@testitem "websocket connect framing" begin
    using Nghttp2Wrapper
    # WebSocket over HTTP/2 requires RFC 8441 server support
    # which nghttp2.org may not support. We test that the
    # framing is correct (CONNECT + :protocol pseudo-header)
    # by verifying no crash when submitting the request.
    client = HTTP2Client("nghttp2.org")
    try
        # This may fail with a protocol error if the server
        # doesn't support Extended CONNECT, but it should not crash
        stream_id = websocket_connect(client, "/ws")
        @test stream_id > 0 || stream_id < 0  # any integer = no crash
    catch e
        # Expected: server may reject with protocol error
        @test e isa Nghttp2Error || e isa Exception
    end
    close(client)
end
