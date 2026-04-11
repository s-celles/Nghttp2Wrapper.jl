@testitem "NVPair from strings" begin
    using Nghttp2Wrapper
    nv = NVPair(":method", "GET")
    @test nv.name == Vector{UInt8}(":method")
    @test nv.value == Vector{UInt8}("GET")
end

@testitem "NVPair to Nghttp2Nv" begin
    using Nghttp2Wrapper
    nv = NVPair(":method", "GET")
    cnv = to_nghttp2_nv(nv)
    @test cnv.namelen == 7
    @test cnv.valuelen == 3
    @test cnv.flags == NGHTTP2_NV_FLAG_NONE
    GC.@preserve nv begin
        @test unsafe_string(cnv.name, cnv.namelen) == ":method"
        @test unsafe_string(cnv.value, cnv.valuelen) == "GET"
    end
end

@testitem "NVPair show" begin
    using Nghttp2Wrapper
    nv = NVPair(":method", "GET")
    s = sprint(show, nv)
    @test occursin(":method", s)
    @test occursin("GET", s)
    @test occursin("NVPair", s)
end
