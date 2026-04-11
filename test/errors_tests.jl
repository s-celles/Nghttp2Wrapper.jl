@testitem "Nghttp2Error construction" begin
    using Nghttp2Wrapper
    e = Nghttp2Error(-501)
    @test e.code == -501
    @test e.msg isa String
    @test !isempty(e.msg)
    @test e.fatal == false
end

@testitem "Nghttp2Error fatal" begin
    using Nghttp2Wrapper
    e = Nghttp2Error(-901)
    @test e.code == -901
    @test e.fatal == true
end

@testitem "check_error helper" begin
    using Nghttp2Wrapper
    @test check_error(0) == 0
    @test check_error(42) == 42
    @test_throws Nghttp2Error check_error(-501)
    try
        check_error(-501)
    catch e
        @test e isa Nghttp2Error
        @test e.code == -501
    end
end

@testitem "Nghttp2Error showerror" begin
    using Nghttp2Wrapper
    e = Nghttp2Error(-501)
    msg = sprint(showerror, e)
    @test occursin("-501", msg)
    @test occursin(e.msg, msg)
end
