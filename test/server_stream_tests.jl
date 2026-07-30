# ServerStream: the incremental handler surface (ROADMAP Milestone 7).
#
# Tested in isolation from the server: the type is a buffer plus a staging area,
# and its blocking semantics are what the deferred data provider needs. Wiring
# it into HTTP2Server is a separate step.

@testitem "ServerStream: is an IO with a documented surface" begin
    using Nghttp2Wrapper

    @test Nghttp2Wrapper.ServerStream <: IO

    s = Nghttp2Wrapper.ServerStream(Int32(1))
    @test isopen(s)
    @test isempty(Nghttp2Wrapper.response_status(s) === nothing ? [] : [1])
end

@testitem "ServerStream: reads the request body incrementally" begin
    using Nghttp2Wrapper

    s = Nghttp2Wrapper.ServerStream(Int32(1))

    # Nothing has arrived and the peer has not half-closed: not at end.
    Nghttp2Wrapper.push_request_data!(s, Vector{UInt8}("hello"))
    @test !eof(s)
    @test String(readavailable(s)) == "hello"

    # readbytes! fills a caller-owned buffer — no allocation per message.
    Nghttp2Wrapper.push_request_data!(s, Vector{UInt8}("world"))
    buf = Vector{UInt8}(undef, 5)
    @test readbytes!(s, buf, 5) == 5
    @test String(buf) == "world"

    # eof only once the peer has half-closed and the buffer is drained.
    Nghttp2Wrapper.close_request!(s)
    @test eof(s)
end

@testitem "ServerStream: read(io, n) returns at most n bytes" begin
    using Nghttp2Wrapper

    # Base.read(io, n) reads *at most* n bytes. This is pinned deliberately:
    # assuming otherwise capped every request at the flow-control window in a
    # downstream project. A short read is not an error and not end-of-stream.
    s = Nghttp2Wrapper.ServerStream(Int32(1))
    Nghttp2Wrapper.push_request_data!(s, Vector{UInt8}("abc"))

    chunk = read(s, 10)
    @test length(chunk) == 3

    # `eof` deliberately blocks while the peer may still send, so it is not
    # called here: with nothing buffered and no half-close it would wait for
    # ever. That blocking is the point — it is what the deferred data provider
    # needs — but it makes `eof` unusable as an "is anything available right
    # now" probe.
    Nghttp2Wrapper.close_request!(s)
    @test eof(s)
end

@testitem "ServerStream: stages status, headers and trailers" begin
    using Nghttp2Wrapper

    s = Nghttp2Wrapper.ServerStream(Int32(1))
    setstatus(s, 200)
    setheader(s, NVPair("content-type", "application/grpc"))
    write(s, Vector{UInt8}("first"))
    write(s, Vector{UInt8}("second"))
    settrailer(s, [NVPair("grpc-status", "0")])

    @test Nghttp2Wrapper.response_status(s) == 200
    @test any(nv -> String(copy(nv.name)) == "content-type",
              Nghttp2Wrapper.response_headers(s))
    @test String(Nghttp2Wrapper.take_response_data!(s)) == "firstsecond"
    @test any(nv -> String(copy(nv.name)) == "grpc-status",
              Nghttp2Wrapper.response_trailers(s))
end

@testitem "ServerStream: signals whether more response data may come" begin
    using Nghttp2Wrapper

    # This is what the data provider needs: an empty buffer means DEFERRED
    # while the handler is still running, and EOF once it has finished.
    s = Nghttp2Wrapper.ServerStream(Int32(1))
    @test !Nghttp2Wrapper.response_complete(s)

    write(s, Vector{UInt8}("x"))
    @test !Nghttp2Wrapper.response_complete(s)

    Nghttp2Wrapper.take_response_data!(s)
    close(s)
    @test Nghttp2Wrapper.response_complete(s)
    @test !isopen(s)
end
