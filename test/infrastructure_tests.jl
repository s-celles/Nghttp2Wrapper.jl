@testitem "testitem runner works" begin
    @test true
end

@testitem "multiple test items" begin
    @test 1 + 1 == 2
    @test "hello" isa String
end
