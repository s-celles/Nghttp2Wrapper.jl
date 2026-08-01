# Shutdown behaviour of HTTP2Server.
#
# `close` used to set `isopen = false`, close the listener, and then `wait` on
# every connection task with no bound. A connection task blocks inside its read
# waiting for bytes that an idle peer will never send, so `close` could not
# return: the loop condition `while server.isopen && isopen(io)` is only
# re-tested after the read returns.
#
# Every test here spawns `close` and polls for completion rather than calling it
# directly, so a regression fails the test instead of hanging the suite.
#
# The helpers are repeated per test item rather than shared: `@testitem` bodies
# are isolated modules with no file-level state between them. They are written
# as functions on purpose — a bare `for` loop at module top level assigns to a
# *local* under soft-scope rules, silently leaving the outer binding untouched.

@testitem "close returns while a connected peer stays idle" begin
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

    # Open the connection by hand: the 24-byte client connection preface
    # (RFC 7540 §3.5) plus an empty SETTINGS frame is all nghttp2 needs to
    # consider the connection established.
    function establish(sock)
        write(sock, Vector{UInt8}("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"))
        write(sock, UInt8[0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00])
        flush(sock)
        sleep(0.5)
    end

    function await(t, seconds)
        deadline = time() + seconds
        while !istaskdone(t) && time() < deadline
            sleep(0.1)
        end
        return istaskdone(t)
    end

    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing

    # Establish, then send nothing more. This is the shape that hung: the peer
    # is alive, so `isopen(io)` holds, and it is silent, so the server's read
    # never returns.
    establish(sock)

    t = Threads.@spawn close(server)
    @test await(t, 30.0)
    # A task that raised is also "done": assert it actually succeeded.
    @test !istaskfailed(t)
    @test !isopen(server)

    try; close(sock); catch; end
end

@testitem "close tells the peer with GOAWAY" begin
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

    function establish(sock)
        write(sock, Vector{UInt8}("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"))
        write(sock, UInt8[0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00])
        flush(sock)
        sleep(0.5)
    end

    # Scan a raw byte stream for a GOAWAY frame. An HTTP/2 frame header is
    # 3 bytes length, 1 byte type, 1 byte flags, 4 bytes stream id; GOAWAY is
    # type 0x07 (RFC 7540 §6.8).
    function has_goaway(bytes::Vector{UInt8})
        i = 1
        while i + 8 <= length(bytes)
            len = (Int(bytes[i]) << 16) | (Int(bytes[i + 1]) << 8) | Int(bytes[i + 2])
            bytes[i + 3] == 0x07 && return true
            i += 9 + len
        end
        return false
    end

    # A dedicated reader task, not `bytesavailable` polling. On a Julia
    # TCPSocket `bytesavailable` reports only what is already in the Julia-side
    # buffer, which nothing fills unless a read is pending — so with no reader
    # it stays at 0 no matter what the peer sent.
    function spawn_reader(sock)
        received = UInt8[]
        task = Threads.@spawn begin
            try
                while !eof(sock)
                    append!(received, readavailable(sock))
                end
            catch
            end
        end
        return received, task
    end

    function poll(predicate, seconds)
        deadline = time() + seconds
        while true
            predicate() && return true
            time() >= deadline && return false
            sleep(0.1)
        end
    end

    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing

    received, reader = spawn_reader(sock)
    establish(sock)

    # The server's own SETTINGS and its ACK land first. Assert the connection is
    # alive and GOAWAY-free, so anything found afterwards is attributable to the
    # shutdown alone.
    @test poll(() -> length(received) > 0, 15.0)
    @test !has_goaway(received)

    t = Threads.@spawn close(server)
    @test poll(() -> has_goaway(received), 30.0)
    @test !istaskfailed(t)

    try; close(sock); catch; end
end

@testitem "close honours its timeout" begin
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

    function establish(sock)
        write(sock, Vector{UInt8}("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"))
        write(sock, UInt8[0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00])
        flush(sock)
        sleep(0.5)
    end

    function await(t, seconds)
        deadline = time() + seconds
        while !istaskdone(t) && time() < deadline
            sleep(0.05)
        end
        return istaskdone(t)
    end

    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing
    establish(sock)

    started = time()
    t = Threads.@spawn close(server; timeout = 0.5)
    @test await(t, 30.0)
    # Without this the test passes for the wrong reason: an unsupported
    # `timeout` keyword raises immediately, which also makes the task done.
    @test !istaskfailed(t)
    elapsed = time() - started

    # Generous upper bound: the claim under test is that a short timeout is
    # respected at all, not that shutdown is fast. CI machines are slow.
    @test elapsed < 15.0

    try; close(sock); catch; end
end

@testitem "close waits for a handler that is still running" begin
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

    finished = Ref(false)
    entered = Ref(false)

    server = HTTP2Server(0) do req
        entered[] = true
        sleep(2.0)
        finished[] = true
        ServerResponse(200, "slow")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing

    cb = Callbacks()
    rv, session_ptr = nghttp2_session_client_new(cb.ptr)
    @test rv == 0
    nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method", "GET"), NVPair(":path", "/slow"),
               NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session_ptr, C_NULL,
                                pointer(nva), length(nva), C_NULL, C_NULL)
        write(sock, Nghttp2Wrapper._session_send_all(session_ptr))
        flush(sock)
    end

    # Wait until the handler is actually running, so the close below races a
    # genuinely in-flight request rather than an idle connection.
    @test await_flag(entered, 15.0)

    # A timeout comfortably longer than the handler: graceful shutdown must let
    # it finish rather than cutting the connection short.
    t = Threads.@spawn close(server; timeout = 20.0)
    @test await(t, 40.0)
    @test !istaskfailed(t)
    @test finished[]

    nghttp2_session_del(session_ptr)
    close(cb)
    try; close(sock); catch; end
end

@testitem "a forced close does not wait for a busy handler" begin
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
            sleep(0.05)
        end
        return istaskdone(t)
    end

    entered = Ref(false)
    server = HTTP2Server(0) do req
        entered[] = true
        sleep(4.0)
        ServerResponse(200, "slow")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing

    cb = Callbacks()
    rv, session = nghttp2_session_client_new(cb.ptr)
    @test rv == 0
    nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method", "POST"), NVPair(":path", "/busy"),
               NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session, C_NULL, pointer(nva), length(nva),
                                C_NULL, C_NULL)
        write(sock, Nghttp2Wrapper._session_send_all(session))
        flush(sock)
    end

    @test await_flag(entered, 15.0)

    # The connection task holds its lock for the whole receive/handle/send
    # block, so a handler mid-flight holds it too. Sending GOAWAY needs that
    # lock — but GOAWAY is a courtesy, and a caller asking for zero grace is
    # asking not to wait. Blocking here made `timeout = 0` take as long as the
    # handler.
    started = time()
    t = Threads.@spawn close(server; timeout = 0.0)
    @test await(t, 30.0)
    @test !istaskfailed(t)
    @test time() - started < 3.0

    nghttp2_session_del(session)
    close(cb)
    try; close(sock); catch; end
end
