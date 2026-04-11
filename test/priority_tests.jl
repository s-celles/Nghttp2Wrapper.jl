@testitem "PrioritySpec construction" begin
    using Nghttp2Wrapper
    p = PrioritySpec(weight=32)
    @test p.weight == 32
    @test p.dep_stream == 0
    @test p.exclusive == false
end

@testitem "PrioritySpec defaults" begin
    using Nghttp2Wrapper
    p = PrioritySpec()
    @test p.weight == 16
    @test p.dep_stream == 0
    @test p.exclusive == false
end

@testitem "PrioritySpec show" begin
    using Nghttp2Wrapper
    p = PrioritySpec(weight=32, exclusive=true)
    s = sprint(show, p)
    @test occursin("32", s)
    @test occursin("true", s)
end
