@testitem "concurrent connections" begin
    using Nghttp2Wrapper, Sockets
    call_count = Ref(0)

    server = HTTP2Server(0) do req
        call_count[] += 1
        ServerResponse(200, "Response $(call_count[])")
    end
    port = Sockets.getsockname(server.listener)[2]
    sleep(1)

    # Connect multiple clients with retry
    for i in 1:3
        tcp = nothing
        for _ in 1:5
            try
                tcp = Sockets.connect("localhost", port)
                break
            catch
                sleep(0.5)
            end
        end
        tcp === nothing && error("Could not connect to server")
        cb = Callbacks()
        rv, session_ptr = nghttp2_session_client_new(cb.ptr)
        nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                                Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
        headers = [NVPair(":method","GET"), NVPair(":path","/conn$i"),
                   NVPair(":scheme","http"), NVPair(":authority","localhost")]
        nva = [to_nghttp2_nv(nv) for nv in headers]
        GC.@preserve headers nva begin
            nghttp2_submit_request2(session_ptr, C_NULL,
                                    pointer(nva), length(nva), C_NULL, C_NULL)
        end
        out = Nghttp2Wrapper._session_send_all(session_ptr)
        write(tcp, out)
        nghttp2_session_del(session_ptr)
        close(cb)
        close(tcp)
    end

    for _ in 1:30
        yield()
        sleep(0.1)
        call_count[] >= 3 && break
    end

    @test call_count[] >= 3
    close(server)
end
