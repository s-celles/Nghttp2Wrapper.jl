@testitem "submit_settings! typed" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    submit_settings!(session)
    close(session)
end

@testitem "send! typed" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    submit_settings!(session)
    data = send!(session)
    @test data isa Vector{UInt8}
    @test length(data) > 0
    # Should contain HTTP/2 connection preface (24 bytes)
    preface = Vector{UInt8}("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    @test data[1:24] == preface
    close(session)
end

@testitem "recv! typed" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    submit_settings!(session)
    send!(session)  # flush outgoing
    n = recv!(session, UInt8[])
    @test n == 0
    close(session)
end

@testitem "want_read/want_write typed" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    submit_settings!(session)
    @test want_write(session) == true
    close(session)
end

@testitem "submit_ping! typed" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    submit_settings!(session)
    submit_ping!(session)
    close(session)
end

@testitem "submit_goaway! typed" begin
    using Nghttp2Wrapper
    cb = Callbacks()
    session = Session(cb)
    submit_settings!(session)
    submit_goaway!(session, 0, 0)
    close(session)
end
