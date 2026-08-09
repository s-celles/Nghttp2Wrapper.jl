# Server configuration that used to be declared and then dropped
# (ROADMAP Milestone 8).
#
# The failure mode these guard against is silence: a caller configures
# something, gets no error, and does not get the behaviour. So each test asserts
# on what reaches the peer or the handler, not on what was stored.

@testitem "SETTINGS reach the peer" begin
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

    # Decode every SETTINGS frame (type 0x04) into id => value pairs. The
    # payload is 6 bytes per entry: a 2-byte identifier and a 4-byte value, both
    # big-endian (RFC 7540 §6.5.1).
    function settings_sent(bytes::Vector{UInt8})
        out = Dict{Int,UInt32}()
        i = 1
        while i + 8 <= length(bytes)
            len = (Int(bytes[i]) << 16) | (Int(bytes[i + 1]) << 8) | Int(bytes[i + 2])
            i + 8 + len > length(bytes) && break
            if bytes[i + 3] == 0x04
                p = i + 9
                while p + 5 <= i + 8 + len
                    id = (Int(bytes[p]) << 8) | Int(bytes[p + 1])
                    v = (UInt32(bytes[p + 2]) << 24) | (UInt32(bytes[p + 3]) << 16) |
                        (UInt32(bytes[p + 4]) << 8) | UInt32(bytes[p + 5])
                    out[id] = v
                    p += 6
                end
            end
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

    server = HTTP2Server(0; max_concurrent_streams = 7,
                         initial_window_size = 123456,
                         max_frame_size = 32768,
                         max_header_list_size = 4096) do req
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing
    received = spawn_reader(sock)
    write(sock, Vector{UInt8}("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"))
    write(sock, UInt8[0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00])
    flush(sock)

    @test poll(() -> haskey(settings_sent(received),
                            Int(NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS)), 20.0)
    got = settings_sent(received)
    @test got[Int(NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS)] == 7
    @test got[Int(NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE)] == 123456
    @test got[Int(NGHTTP2_SETTINGS_MAX_FRAME_SIZE)] == 32768
    @test got[Int(NGHTTP2_SETTINGS_MAX_HEADER_LIST_SIZE)] == 4096

    try; close(sock); catch; end
    close(server)
end

@testitem "a server with no settings configured sends none" begin
    using Nghttp2Wrapper, Sockets

    # The default must stay an empty SETTINGS frame: sending values nobody asked
    # for would change protocol behaviour for every existing user.
    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    @test isempty(Nghttp2Wrapper._settings_entries(server))
    close(server)
end

@testitem "the handler can tell who is calling" begin
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

    seen = Ref{Any}(nothing)
    server = HTTP2Server(0) do req
        seen[] = peer_address(req)
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    sock = connect_retry(port)
    @test sock !== nothing
    local_port = Sockets.getsockname(sock)[2]

    cb = Callbacks()
    rv, session = nghttp2_session_client_new(cb.ptr)
    @test rv == 0
    nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method", "GET"), NVPair(":path", "/who"),
               NVPair(":scheme", "http"), NVPair(":authority", "localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session, C_NULL, pointer(nva), length(nva),
                                C_NULL, C_NULL)
        write(sock, Nghttp2Wrapper._session_send_all(session))
        flush(sock)
    end

    @test poll(() -> seen[] !== nothing, 20.0)
    # Asserted against the client's own socket, so this is the real endpoint and
    # not a value we merely stored somewhere.
    @test seen[] isa Sockets.InetAddr
    @test seen[].host == Sockets.ip"127.0.0.1"
    @test seen[].port == local_port

    nghttp2_session_del(session)
    close(cb)
    try; close(sock); catch; end
    close(server)
end
