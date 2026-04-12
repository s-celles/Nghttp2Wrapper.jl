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
