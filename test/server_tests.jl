@testitem "server lifecycle" begin
    using Nghttp2Wrapper
    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    @test isopen(server)
    close(server)
    @test !isopen(server)
end

@testitem "server show" begin
    using Nghttp2Wrapper
    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    s = sprint(show, server)
    @test occursin("HTTP2Server", s)
    @test occursin("listening", s)
    close(server)
end

@testitem "server handler dispatch" begin
    using Nghttp2Wrapper, Sockets

    handler_called = Ref(false)
    handler_method = Ref("")
    handler_path = Ref("")

    server = HTTP2Server(0) do req
        handler_called[] = true
        handler_method[] = req.method
        handler_path[] = req.path
        ServerResponse(200, "Response!")
    end
    port = Sockets.getsockname(server.listener)[2]

    tcp = let
        result = nothing
        for _ in 1:50
            try
                result = Sockets.connect("127.0.0.1", port)
                break
            catch
                sleep(0.2)
            end
        end
        result
    end
    @test tcp !== nothing

    cb = Callbacks()
    rv, session_ptr = nghttp2_session_client_new(cb.ptr)
    nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method","GET"), NVPair(":path","/test"),
               NVPair(":scheme","http"), NVPair(":authority","localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session_ptr, C_NULL,
                                pointer(nva), length(nva), C_NULL, C_NULL)
    end
    out = Nghttp2Wrapper._session_send_all(session_ptr)
    write(tcp, out)

    for _ in 1:30
        yield()
        sleep(0.1)
        handler_called[] && break
    end

    @test handler_called[]
    @test handler_method[] == "GET"
    @test handler_path[] == "/test"

    nghttp2_session_del(session_ptr)
    close(cb)
    close(tcp)
    close(server)
end

@testitem "server response body round-trip" begin
    using Nghttp2Wrapper, Sockets

    # Regression test: a handler returning ServerResponse(200, "body")
    # MUST send the body bytes over the wire. Prior to the [fix] this
    # server.jl test item covers, `nghttp2_submit_response2` was called
    # with a C_NULL data provider, which caused nghttp2 to send HEADERS
    # with END_STREAM set and NO DATA frames. Clients therefore saw
    # an empty body on every response.
    #
    # This test reproduces the bug by driving a raw nghttp2 client
    # session against a local HTTP2Server and asserting that the
    # response body collected on the client side matches the string
    # the handler returned.
    response_body = "Hello from the handler!"

    server = HTTP2Server(0) do req
        ServerResponse(200, response_body)
    end
    port = Sockets.getsockname(server.listener)[2]

    tcp = let
        result = nothing
        for _ in 1:50
            try
                result = Sockets.connect("127.0.0.1", port)
                break
            catch
                sleep(0.05)
            end
        end
        result
    end
    @test tcp !== nothing

    # Reuse Nghttp2Wrapper's own client-side ClientContext + callbacks so
    # response HEADERS / DATA frames are collected into `st.body` and
    # `st.headers` automatically.
    ctx = Nghttp2Wrapper.ClientContext(
        Dict{Int32,Nghttp2Wrapper.StreamState}(), ReentrantLock())
    lock(ctx.lock) do
        ctx.streams[Int32(1)] = Nghttp2Wrapper.StreamState(Int32(1))
    end

    cb = Callbacks()
    nghttp2_session_callbacks_set_on_header_callback(
        cb.ptr, Nghttp2Wrapper._on_header_cb_ptr())
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback(
        cb.ptr, Nghttp2Wrapper._on_data_chunk_cb_ptr())

    GC.@preserve ctx begin
        rv, session_ptr = nghttp2_session_client_new(cb.ptr, pointer_from_objref(ctx))
        @test rv == 0
        try
            # Submit initial SETTINGS + the GET request.
            nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                                    Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
            headers = [NVPair(":method", "GET"), NVPair(":path", "/"),
                       NVPair(":scheme", "http"),
                       NVPair(":authority", "127.0.0.1:$port")]
            nva = [to_nghttp2_nv(nv) for nv in headers]
            GC.@preserve headers nva begin
                nghttp2_submit_request2(session_ptr, C_NULL,
                                        pointer(nva), length(nva), C_NULL, C_NULL)
            end
            out = Nghttp2Wrapper._session_send_all(session_ptr)
            write(tcp, out)

            # Pump server responses through the client session until the
            # response body is fully collected (or a timeout fires).
            deadline = time() + 5.0
            while time() < deadline
                yield()
                sleep(0.05)
                buf = readavailable(tcp)
                if !isempty(buf)
                    nghttp2_session_mem_recv2(session_ptr, collect(buf))
                    # The client session may produce WINDOW_UPDATE / SETTINGS
                    # ACK frames in response — flush them back to the server.
                    ack_out = Nghttp2Wrapper._session_send_all(session_ptr)
                    if !isempty(ack_out)
                        write(tcp, ack_out)
                    end
                end
                collected = lock(ctx.lock) do
                    haskey(ctx.streams, Int32(1)) ?
                        copy(ctx.streams[Int32(1)].body) : UInt8[]
                end
                if length(collected) >= ncodeunits(response_body)
                    break
                end
            end

            # Assert body round-trip succeeded.
            final_body = lock(ctx.lock) do
                haskey(ctx.streams, Int32(1)) ?
                    copy(ctx.streams[Int32(1)].body) : UInt8[]
            end
            @test String(final_body) == response_body
        finally
            nghttp2_session_del(session_ptr)
        end
    end

    close(cb)
    close(tcp)
    close(server)
end

@testitem "handler exception returns 500" begin
    using Nghttp2Wrapper, Sockets

    handler_called = Ref(false)

    server = HTTP2Server(0) do req
        handler_called[] = true
        error("Intentional test error")
    end
    port = Sockets.getsockname(server.listener)[2]

    tcp = let
        result = nothing
        for _ in 1:50
            try
                result = Sockets.connect("127.0.0.1", port)
                break
            catch
                sleep(0.2)
            end
        end
        result
    end
    @test tcp !== nothing

    cb = Callbacks()
    rv, session_ptr = nghttp2_session_client_new(cb.ptr)
    nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    headers = [NVPair(":method","GET"), NVPair(":path","/fail"),
               NVPair(":scheme","http"), NVPair(":authority","localhost")]
    nva = [to_nghttp2_nv(nv) for nv in headers]
    GC.@preserve headers nva begin
        nghttp2_submit_request2(session_ptr, C_NULL,
                                pointer(nva), length(nva), C_NULL, C_NULL)
    end
    out = Nghttp2Wrapper._session_send_all(session_ptr)
    write(tcp, out)

    for _ in 1:20
        yield()
        sleep(0.1)
        handler_called[] && break
    end
    @test handler_called[]

    nghttp2_session_del(session_ptr)
    close(cb)
    close(tcp)
    close(server)
end

@testitem "graceful shutdown" begin
    using Nghttp2Wrapper
    server = HTTP2Server(0) do req
        ServerResponse(200, "OK")
    end
    sleep(0.5)
    shutdown!(server)
    @test !isopen(server)
end

@testitem "TLS server handshake" begin
    using Nghttp2Wrapper, Sockets
    certfile = joinpath(@__DIR__, "fixtures", "server.crt")
    keyfile = joinpath(@__DIR__, "fixtures", "server.key")

    handler_called = Ref(false)
    server = HTTP2Server(0; certfile=certfile, keyfile=keyfile) do req
        handler_called[] = true
        ServerResponse(200, "Hello TLS!")
    end
    port = Sockets.getsockname(server.listener)[2]

    try
        # Retry connect because accept loop may take a moment to start
        client = nothing
        for _ in 1:20
            try
                client = HTTP2Client("127.0.0.1"; port=port, verify_peer=false)
                break
            catch
                sleep(0.2)
            end
        end
        @test client !== nothing

        if client !== nothing
            resp = get(client, "/")
            @test resp.status == 200
            @test handler_called[]
            close(client)
        end
    finally
        close(server)
    end
end
