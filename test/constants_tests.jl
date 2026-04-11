@testitem "constants defined" begin
    using Nghttp2Wrapper
    @test NGHTTP2_ERR_INVALID_ARGUMENT == -501
    @test NGHTTP2_ERR_WOULDBLOCK == -504
    @test NGHTTP2_ERR_FATAL == -900
    @test NGHTTP2_ERR_NOMEM == -901
    @test NGHTTP2_ERR_CALLBACK_FAILURE == -902
    @test NGHTTP2_ERR_TOO_MANY_SETTINGS == -537
    @test NGHTTP2_NV_FLAG_NONE == 0x00
    @test NGHTTP2_NV_FLAG_NO_INDEX == 0x01
    @test NGHTTP2_SETTINGS_HEADER_TABLE_SIZE == 0x01
    @test NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS == 0x03
end

@testitem "types layout" begin
    using Nghttp2Wrapper
    # Nghttp2Nv: Ptr + Ptr + Csize_t + Csize_t + UInt8 (+ padding)
    @test sizeof(Nghttp2Nv) >= 4 * sizeof(Ptr{Cvoid}) + 1
    # Nghttp2SettingsEntry: Int32 + UInt32 = 8 bytes
    @test sizeof(Nghttp2SettingsEntry) == 8
end
