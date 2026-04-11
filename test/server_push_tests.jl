@testitem "server push placeholder" begin
    using Nghttp2Wrapper
    @test isdefined(Nghttp2Wrapper, :HTTP2Server)
    @test true
end
