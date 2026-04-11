@testitem "hpack lifecycle" begin
    using Nghttp2Wrapper
    rv_d, deflater = nghttp2_hd_deflate_new()
    @test rv_d == 0
    @test deflater != C_NULL
    nghttp2_hd_deflate_del(deflater)

    rv_i, inflater = nghttp2_hd_inflate_new()
    @test rv_i == 0
    @test inflater != C_NULL
    nghttp2_hd_inflate_del(inflater)
end

@testitem "hpack deflate" begin
    using Nghttp2Wrapper
    rv, deflater = nghttp2_hd_deflate_new()
    @test rv == 0

    # Create headers
    method = Vector{UInt8}(":method")
    get = Vector{UInt8}("GET")
    path = Vector{UInt8}(":path")
    slash = Vector{UInt8}("/")

    nva = [
        Nghttp2Nv(pointer(method), pointer(get), length(method), length(get), NGHTTP2_NV_FLAG_NONE),
        Nghttp2Nv(pointer(path), pointer(slash), length(path), length(slash), NGHTTP2_NV_FLAG_NONE),
    ]

    buf = Vector{UInt8}(undef, 4096)
    nbytes = nghttp2_hd_deflate_hd2(deflater, buf, nva)
    @test nbytes > 0

    nghttp2_hd_deflate_del(deflater)
    GC.@preserve method get path slash nva nothing
end

@testitem "hpack round-trip" begin
    using Nghttp2Wrapper
    rv_d, deflater = nghttp2_hd_deflate_new()
    rv_i, inflater = nghttp2_hd_inflate_new()

    # Compress
    method = Vector{UInt8}(":method")
    get = Vector{UInt8}("GET")

    nva = [
        Nghttp2Nv(pointer(method), pointer(get), length(method), length(get), NGHTTP2_NV_FLAG_NONE),
    ]

    buf = Vector{UInt8}(undef, 4096)
    nbytes = nghttp2_hd_deflate_hd2(deflater, buf, nva)
    @test nbytes > 0

    # Decompress
    compressed = buf[1:nbytes]
    nv_out = Ref(Nghttp2Nv(Ptr{UInt8}(0), Ptr{UInt8}(0), 0, 0, 0))
    inflate_flags = Ref(Cint(0))

    processed = nghttp2_hd_inflate_hd2(inflater, nv_out, inflate_flags,
                                        pointer(compressed), length(compressed), 1)
    @test processed > 0

    # Check that we got a header emitted
    if inflate_flags[] & NGHTTP2_HD_INFLATE_EMIT != 0
        decoded_name = unsafe_string(nv_out[].name, nv_out[].namelen)
        decoded_value = unsafe_string(nv_out[].value, nv_out[].valuelen)
        @test decoded_name == ":method"
        @test decoded_value == "GET"
    end

    nghttp2_hd_deflate_del(deflater)
    nghttp2_hd_inflate_del(inflater)
    GC.@preserve method get nva compressed nothing
end
