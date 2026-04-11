@testitem "streaming response" begin
    using Nghttp2Wrapper
    client = HTTP2Client("nghttp2.org")
    done_ch, chunks_ch = request_stream(client, "GET", "/")
    collected = UInt8[]
    for chunk in chunks_ch
        append!(collected, chunk)
    end
    resp = take!(done_ch)
    @test resp.status == 200
    @test !isempty(collected)
    close(client)
end
