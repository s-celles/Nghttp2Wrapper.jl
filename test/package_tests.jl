@testitem "package loads" begin
    using Nghttp2Wrapper
    @test isdefined(Nghttp2Wrapper, :nghttp2_jll)
end

@testitem "nghttp2_jll available" begin
    using nghttp2_jll
    @test nghttp2_jll.is_available()
    @test !isempty(nghttp2_jll.libnghttp2)
end
