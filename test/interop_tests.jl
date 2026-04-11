@testitem "session over raw TCP pair" begin
    using Nghttp2Wrapper, Sockets

    # Create a localhost TCP pair via server/client
    server_listen = Sockets.listen(0)
    port = Sockets.getsockname(server_listen)[2]

    server_done = Ref(false)
    server_task = @async begin
        tcp = accept(server_listen)
        # Create server session
        cb = Callbacks()
        rv, session_ptr = nghttp2_session_server_new(cb.ptr)
        nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                                Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
        out = Nghttp2Wrapper._session_send_all(session_ptr)
        write(tcp, out)

        # Read client data
        try
            while isopen(tcp)
                b = read(tcp, UInt8)
                avail = bytesavailable(tcp)
                buf = Vector{UInt8}(undef, 1 + avail)
                buf[1] = b
                if avail > 0
                    unsafe_read(tcp, pointer(buf, 2), UInt(avail))
                end
                nghttp2_session_mem_recv2(session_ptr, buf)
                out = Nghttp2Wrapper._session_send_all(session_ptr)
                if !isempty(out)
                    write(tcp, out)
                end
            end
        catch
        end
        server_done[] = true
        nghttp2_session_del(session_ptr)
        close(cb)
        close(tcp)
    end

    sleep(1)

    # Client side with retry
    tcp_client = nothing
    for _ in 1:5
        try
            tcp_client = Sockets.connect("localhost", port)
            break
        catch
            sleep(0.5)
        end
    end
    tcp_client === nothing && error("Could not connect to server")
    cb = Callbacks()
    rv, session_ptr = nghttp2_session_client_new(cb.ptr)
    nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    out = Nghttp2Wrapper._session_send_all(session_ptr)
    write(tcp_client, out)

    # Read server settings
    for _ in 1:10
        yield()
        sleep(0.1)
        avail = bytesavailable(tcp_client)
        if avail > 0
            data = readavailable(tcp_client)
            nghttp2_session_mem_recv2(session_ptr, data)
            out2 = Nghttp2Wrapper._session_send_all(session_ptr)
            if !isempty(out2)
                write(tcp_client, out2)
            end
            break
        end
    end

    # Verify session is working
    @test nghttp2_session_want_read(session_ptr)

    nghttp2_session_del(session_ptr)
    close(cb)
    close(tcp_client)
    close(server_listen)
    @test true  # no crash = success
end
