@testitem "docs build without warnings" begin
    docs_dir = joinpath(dirname(@__DIR__), "docs")
    make_jl = joinpath(docs_dir, "make.jl")
    @test isfile(make_jl)
    @test isfile(joinpath(docs_dir, "Project.toml"))
    @test isfile(joinpath(docs_dir, "src", "index.md"))
end
