@testitem "ConnectionPool lifecycle" begin
    using Nghttp2Wrapper
    pool = ConnectionPool()
    @test isopen(pool)
    close(pool)
    @test !isopen(pool)
end

@testitem "pool show" begin
    using Nghttp2Wrapper
    pool = ConnectionPool()
    s = sprint(show, pool)
    @test occursin("ConnectionPool", s)
    @test occursin("open", s)
    close(pool)
end

@testitem "pool reuses connection" begin
    using Nghttp2Wrapper
    pool = ConnectionPool()
    c1 = acquire(pool, "nghttp2.org")
    @test isopen(c1)
    id1 = objectid(c1)
    release(pool, c1)
    c2 = acquire(pool, "nghttp2.org")
    @test objectid(c2) == id1  # same object reused
    close(c2)
    close(pool)
end

@testitem "pool_get convenience" begin
    using Nghttp2Wrapper
    pool = ConnectionPool()
    resp = pool_get(pool, "https://nghttp2.org/")
    @test resp.status == 200
    @test !isempty(resp.body)
    close(pool)
end
