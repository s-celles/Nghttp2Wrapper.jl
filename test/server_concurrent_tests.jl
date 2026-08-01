@testitem "concurrent connections" begin
    using Nghttp2Wrapper, Sockets
    # Atomic, not `Ref(0)`. Three connections are now in flight at once, and
    # their handlers run on different tasks: `count[] += 1` is a load, an add
    # and a store, so concurrent increments are lost. That is what made this
    # test report "1 >= 3" while the server had in fact served all three.
    call_count = Threads.Atomic{Int}(0)

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

    server = HTTP2Server(0) do req
        n = Threads.atomic_add!(call_count, 1) + 1
        ServerResponse(200, "Response $(n)")
    end
    port = Nghttp2Wrapper.listener_port(server)

    # Open every connection, send every request, and only then close anything.
    #
    # Each client used to sleep 0.5s after writing and close regardless. That is
    # an arbitrary window on how long the server may take to read, and closing
    # first loses the request outright — so on a loaded machine one of the three
    # calls simply never happened and the test failed by two-against-three.
    # Holding the connections open until the server has answered removes the
    # race rather than widening it.
    conns = Any[]
    for i in 1:3
        tcp = connect_retry(port)
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
        flush(tcp)
        push!(conns, (tcp, session_ptr, cb))
    end

    deadline = time() + 30
    while call_count[] < 3 && time() < deadline
        sleep(0.05)
    end

    @test call_count[] >= 3

    for (tcp, session_ptr, cb) in conns
        nghttp2_session_del(session_ptr)
        close(cb)
        try; close(tcp); catch; end
    end
    close(server)
end
