@testitem "nghttp2_version" begin
    using Nghttp2Wrapper
    info_ptr = nghttp2_version()
    @test info_ptr != C_NULL
    info = unsafe_load(info_ptr)
    @test info.version_num > 0
    @test !isempty(unsafe_string(info.version_str))
    @test !isempty(unsafe_string(info.proto_str))
end

@testitem "nghttp2_strerror" begin
    using Nghttp2Wrapper
    msg = nghttp2_strerror(NGHTTP2_ERR_INVALID_ARGUMENT)
    @test msg isa String
    @test !isempty(msg)
    # Also test a fatal error
    msg_fatal = nghttp2_strerror(NGHTTP2_ERR_NOMEM)
    @test !isempty(msg_fatal)
end

@testitem "nghttp2_is_fatal" begin
    using Nghttp2Wrapper
    @test nghttp2_is_fatal(NGHTTP2_ERR_NOMEM) == true
    @test nghttp2_is_fatal(NGHTTP2_ERR_CALLBACK_FAILURE) == true
    @test nghttp2_is_fatal(NGHTTP2_ERR_WOULDBLOCK) == false
    @test nghttp2_is_fatal(NGHTTP2_ERR_INVALID_ARGUMENT) == false
    @test nghttp2_is_fatal(0) == false
end
