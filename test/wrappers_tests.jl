@testitem "Callbacks lifecycle" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    @test isopen(cb) == true
    close(cb)
    @test isopen(cb) == false
    close(cb)  # idempotent, no error
end

@testitem "Option lifecycle" begin
    using Nghttp2Wrapper
    opt = Option()
    @test isopen(opt) == true
    close(opt)
    @test isopen(opt) == false
    close(opt)  # idempotent
end

@testitem "Session lifecycle" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    @test isopen(session) == true
    close(session)
    @test isopen(session) == false
end

@testitem "Session double close" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    close(session)
    close(session)  # idempotent, no error
    @test isopen(session) == false
end

@testitem "Session use after close" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    close(session)
    @test_throws ArgumentError submit_settings!(session)
end

@testitem "Session constructor failure" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    close(cb)
    @test_throws ArgumentError Session(cb)
end

@testitem "GC cleanup" begin
    using Nghttp2Wrapper
    for _ in 1:100
        cb = Callbacks()
        session = Session(cb)
        # Let them go out of scope without closing
    end
    GC.gc()
    GC.gc()
    @test true  # No crash = success
end

@testitem "Session show" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    s = sprint(show, session)
    @test occursin("Session", s)
    @test occursin("open", s)
    close(session)
    s2 = sprint(show, session)
    @test occursin("closed", s2)
end

@testitem "Callbacks show" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    s = sprint(show, cb)
    @test occursin("Callbacks", s)
    close(cb)
end
