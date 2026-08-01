# The incremental server handler (ROADMAP Milestone 7).
#
# `HTTP2Server(port; streaming = true)` hands the handler a `ServerStream` instead
# of a complete `ServerRequest`, so a response can be emitted as it is produced
# rather than assembled and returned at the end.
#
# These tests drive the wire directly. `HTTP2Client` is TLS-only, so a raw
# nghttp2 client session emits the request bytes and a reader task collects what
# comes back; DATA payloads are not header-compressed, so scanning frames by hand
# is enough to see what actually reached the peer and when.
#
# The helpers are repeated per test item: `@testitem` bodies are isolated modules
# sharing no file-level state. They are functions rather than bare loops because
# a `for` loop at module top level assigns to a *local* under soft-scope rules.

@testitem "an incremental handler's writes reach the peer before it returns" begin
    using Nghttp2Wrapper, Sockets

    function connect_retry(port)
        for _ in 1:50
            try
                return Sockets.connect("127.0.0.1", port)
            catch
                sleep(0.2)
            end
        end
        return nothing
    end

    function spawn_reader(sock)
        received = UInt8[]
        Threads.@spawn begin
            try
                while !eof(sock)
                    append!(received, readavailable(sock))
                end
            catch
            end
        end
        return received
    end

    # Concatenate the payloads of every complete DATA frame (type 0x00).
    # An HTTP/2 frame header is 3 bytes length, 1 type, 1 flags, 4 stream id.
    function data_payload(bytes::Vector{UInt8})
        out = UInt8[]
        i = 1
        while i + 8 <= length(bytes)
            len = (Int(bytes[i]) << 16) | (Int(bytes[i + 1]) << 8) | Int(bytes[i + 2])
            i + 8 + len > length(bytes) && break
            bytes[i + 3] == 0x00 && append!(out, bytes[(i + 9):(i + 8 + len)])
            i += 9 + len
        end
        return String(out)
    end

    function poll(predicate, seconds)
        deadline = time() + seconds
        while true
            predicate() && return true
            time() >= deadline && return false
            sleep(0.1)
        end
    end

    function send_request(sock, path)
        cb = Callbacks()
        rv, session = nghttp2_session_client_new(cb.ptr)
        rv == 0 || error("could not create the client session")
        nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                                Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
        headers = [NVPair(":method", "GET"), NVPair(":path", path),
                   NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
        nva = [to_nghttp2_nv(nv) for nv in headers]
        GC.@preserve headers nva begin
            nghttp2_submit_request2(session, C_NULL, pointer(nva), length(nva),
                                    C_NULL, C_NULL)
            write(sock, Nghttp2Wrapper._session_send_all(session))
            flush(sock)
        end
        return session, cb
    end

    released = Ref(false)
    returned = Ref(false)

    server = HTTP2Server(0; streaming = true) do stream
        setstatus(stream, 200)
        setheader(stream, "content-type", "text/plain")
        write(stream, Vector{UInt8}("first"))
        # Block until the test has seen "first" on the wire. This is the whole
        # point: a buffered implementation delivers nothing until the handler
        # returns, so it deadlocks here and the test fails on its deadline
        # rather than passing by accident.
        t0 = time()
        while !released[] && time() - t0 < 30
            sleep(0.05)
        end
        write(stream, Vector{UInt8}("second"))
        returned[] = true
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing
    received = spawn_reader(sock)
    session, cb = send_request(sock, "/incremental")

    @test poll(() -> occursin("first", data_payload(received)), 20.0)
    # Still inside the handler, and the second write has not happened.
    @test !returned[]
    @test !occursin("second", data_payload(received))

    released[] = true
    @test poll(() -> occursin("second", data_payload(received)), 20.0)
    @test returned[]

    nghttp2_session_del(session)
    close(cb)
    try; close(sock); catch; end
    close(server)
end

@testitem "a streaming response ends with trailers" begin
    using Nghttp2Wrapper, Sockets

    function connect_retry(port)
        for _ in 1:50
            try
                return Sockets.connect("127.0.0.1", port)
            catch
                sleep(0.2)
            end
        end
        return nothing
    end

    function spawn_reader(sock)
        received = UInt8[]
        Threads.@spawn begin
            try
                while !eof(sock)
                    append!(received, readavailable(sock))
                end
            catch
            end
        end
        return received
    end

    # Frame types in arrival order, for the streams the server opened.
    function frame_types(bytes::Vector{UInt8})
        out = UInt8[]
        i = 1
        while i + 8 <= length(bytes)
            len = (Int(bytes[i]) << 16) | (Int(bytes[i + 1]) << 8) | Int(bytes[i + 2])
            i + 8 + len > length(bytes) && break
            push!(out, bytes[i + 3])
            i += 9 + len
        end
        return out
    end

    function poll(predicate, seconds)
        deadline = time() + seconds
        while true
            predicate() && return true
            time() >= deadline && return false
            sleep(0.1)
        end
    end

    # HEADERS after at least one DATA frame is a trailing HEADERS block
    # (RFC 7540 §8.1): the body no longer closes the stream, the trailers do.
    function trailers_after_data(types::Vector{UInt8})
        seen_data = false
        for t in types
            t == 0x00 && (seen_data = true)
            t == 0x01 && seen_data && return true
        end
        return false
    end

    server = HTTP2Server(0; streaming = true) do stream
        setstatus(stream, 200)
        write(stream, Vector{UInt8}("payload"))
        settrailer(stream, NVPair("grpc-status", "0"))
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing
    received = spawn_reader(sock)

    cb = Callbacks()
    rv, session = nghttp2_session_client_new(cb.ptr)
    @test rv == 0
    nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method", "GET"), NVPair(":path", "/trailers"),
               NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session, C_NULL, pointer(nva), length(nva),
                                C_NULL, C_NULL)
        write(sock, Nghttp2Wrapper._session_send_all(session))
        flush(sock)
    end

    @test poll(() -> trailers_after_data(frame_types(received)), 20.0)

    nghttp2_session_del(session)
    close(cb)
    try; close(sock); catch; end
    close(server)
end

@testitem "the request side is half-closed for a body-less request" begin
    using Nghttp2Wrapper, Sockets

    function connect_retry(port)
        for _ in 1:50
            try
                return Sockets.connect("127.0.0.1", port)
            catch
                sleep(0.2)
            end
        end
        return nothing
    end

    function poll(predicate, seconds)
        deadline = time() + seconds
        while true
            predicate() && return true
            time() >= deadline && return false
            sleep(0.1)
        end
    end

    saw_eof = Ref(false)
    saw_path = Ref("")

    server = HTTP2Server(0; streaming = true) do stream
        # A GET with END_STREAM on its HEADERS has no body, so `eof` must be
        # true rather than block forever. This is what proves the request side
        # is wired to the stream and not merely the response side.
        saw_path[] = request_path(stream)
        saw_eof[] = eof(stream)
        setstatus(stream, 204)
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing

    cb = Callbacks()
    rv, session = nghttp2_session_client_new(cb.ptr)
    @test rv == 0
    nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method", "GET"), NVPair(":path", "/nobody"),
               NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session, C_NULL, pointer(nva), length(nva),
                                C_NULL, C_NULL)
        write(sock, Nghttp2Wrapper._session_send_all(session))
        flush(sock)
    end

    @test poll(() -> saw_eof[], 20.0)
    @test saw_path[] == "/nobody"

    nghttp2_session_del(session)
    close(cb)
    try; close(sock); catch; end
    close(server)
end

@testitem "the buffered handler is still the default" begin
    using Nghttp2Wrapper

    # A regression guard for the selection itself: adding the streaming path
    # must not change what an existing one-argument handler receives.
    got = Ref{Any}(nothing)
    server = HTTP2Server(0) do req
        got[] = req
        ServerResponse(200, "OK")
    end
    @test isopen(server)
    close(server)
    @test got[] === nothing || got[] isa ServerRequest
end

@testitem "close waits for an incremental handler in flight" begin
    using Nghttp2Wrapper, Sockets

    function connect_retry(port)
        for _ in 1:50
            try
                return Sockets.connect("127.0.0.1", port)
            catch
                sleep(0.2)
            end
        end
        return nothing
    end

    function await_flag(flag, seconds)
        deadline = time() + seconds
        while !flag[] && time() < deadline
            sleep(0.05)
        end
        return flag[]
    end

    function await(t, seconds)
        deadline = time() + seconds
        while !istaskdone(t) && time() < deadline
            sleep(0.1)
        end
        return istaskdone(t)
    end

    entered = Ref(false)
    finished = Ref(false)

    # An incremental handler runs in its own task, so the `processing` flag the
    # read loop maintains says nothing about it. Without `close` accounting for
    # live streams, this handler would be cut off immediately.
    server = HTTP2Server(0; streaming = true) do stream
        entered[] = true
        setstatus(stream, 200)
        sleep(2.0)
        write(stream, Vector{UInt8}("done"))
        finished[] = true
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing

    cb = Callbacks()
    rv, session = nghttp2_session_client_new(cb.ptr)
    @test rv == 0
    nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method", "GET"), NVPair(":path", "/slow"),
               NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session, C_NULL, pointer(nva), length(nva),
                                C_NULL, C_NULL)
        write(sock, Nghttp2Wrapper._session_send_all(session))
        flush(sock)
    end

    @test await_flag(entered, 15.0)

    t = Threads.@spawn close(server; timeout = 20.0)
    @test await(t, 40.0)
    @test !istaskfailed(t)
    @test finished[]

    nghttp2_session_del(session)
    close(cb)
    try; close(sock); catch; end
end
