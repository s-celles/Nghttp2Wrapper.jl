"""
Internal state for a server-side HTTP/2 stream (accumulating a request).
"""
mutable struct ServerStreamState
    id::Int32
    method::String
    path::String
    headers::Vector{NVPair}
    body::Vector{UInt8}
end

ServerStreamState(id::Int32) = ServerStreamState(id, "", "", NVPair[], UInt8[])

"""
Internal context for server-side nghttp2 callbacks.
"""
mutable struct ServerContext
    streams::Dict{Int32,ServerStreamState}
    handler::Function
    session_ptr::Ptr{Cvoid}
    io_stream::IO
    lock::ReentrantLock
end

"""
    HTTP2Server(handler, port; host="0.0.0.0")

Create an HTTP/2 server listening on the given port.
Uses cleartext HTTP/2 (h2c) — clients must use HTTP/2 prior knowledge.
The handler function receives a `ServerRequest` and returns a `ServerResponse`.

# Examples
```julia
server = HTTP2Server(8080) do req
    ServerResponse(200, "Hello HTTP/2!")
end
close(server)
```
"""
mutable struct HTTP2Server
    listener::Sockets.TCPServer
    handler::Function
    connections::Vector{Task}
    isopen::Bool
    accept_task::Task

    function HTTP2Server(handler::Function, port::Integer;
                         host::AbstractString="0.0.0.0")
        listener = Sockets.listen(Sockets.InetAddr(host, port))
        server = new(listener, handler, Task[], true, Task(() -> nothing))
        server.accept_task = Threads.@spawn _server_accept_loop(server)
        return server
    end
end

# Do-block syntax: HTTP2Server(port) do req ... end
# Julia passes the do-block function as first argument

function Base.close(server::HTTP2Server)
    if server.isopen
        server.isopen = false
        try; close(server.listener); catch; end
        for t in server.connections
            try; wait(t); catch; end
        end
    end
    return nothing
end

Base.isopen(server::HTTP2Server) = server.isopen

function Base.show(io::IO, server::HTTP2Server)
    state = server.isopen ? "listening" : "closed"
    n = length(server.connections)
    print(io, "HTTP2Server($(state), $(n) connections)")
end

"""
    shutdown!(server::HTTP2Server)

Gracefully shut down the server: stop accepting new connections,
wait for in-flight requests to complete.
"""
function shutdown!(server::HTTP2Server)
    server.isopen = false
    try; close(server.listener); catch; end
    for t in server.connections
        try; wait(t); catch; end
    end
end

function _server_accept_loop(server::HTTP2Server)
    try
        while server.isopen
            tcp = try
                accept(server.listener)
            catch
                break
            end

            # Spawn connection handler (h2c — cleartext HTTP/2)
            t = Threads.@spawn _server_connection_handler(server, tcp)
            push!(server.connections, t)

            # Clean up completed connections
            filter!(t -> !istaskdone(t), server.connections)
        end
    catch
    end
end

function _server_connection_handler(server::HTTP2Server, io::IO)
    ctx = ServerContext(
        Dict{Int32,ServerStreamState}(),
        server.handler,
        C_NULL,
        io,
        ReentrantLock()
    )

    cb = Callbacks()
    nghttp2_session_callbacks_set_on_header_callback(cb.ptr, _server_on_header_cb_ptr())
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback(cb.ptr, _server_on_data_chunk_cb_ptr())
    nghttp2_session_callbacks_set_on_frame_recv_callback(cb.ptr, _server_on_frame_recv_cb_ptr())

    # Pass ctx directly — mutable structs are heap-allocated and stable
    rv, session_ptr = nghttp2_session_server_new(cb.ptr, pointer_from_objref(ctx))
    if rv != 0
        close(cb)
        try; close(io); catch; end
        return
    end
    ctx.session_ptr = session_ptr

    # Send server settings
    nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    outdata = _session_send_all(session_ptr)
    if !isempty(outdata)
        try; write(io, outdata); catch; end
    end

    # I/O loop — read raw TCP data and feed to nghttp2
    # GC.@preserve ensures ctx stays alive while C code holds a pointer to it
    GC.@preserve ctx begin
        buf = Vector{UInt8}(undef, 65536)
        try
            while server.isopen && isopen(io)
                nbytes = try
                    buf[1] = read(io, UInt8)
                    avail = bytesavailable(io)
                    if avail > 0
                        extra = min(avail, length(buf) - 1)
                        unsafe_read(io, pointer(buf, 2), UInt(extra))
                        1 + Int(extra)
                    else
                        1
                    end
                catch
                    0
                end

                if nbytes == 0
                    break
                end

                try
                    nghttp2_session_mem_recv2(session_ptr, buf[1:nbytes])
                catch
                    break
                end

                try
                    outdata = _session_send_all(session_ptr)
                    if !isempty(outdata)
                        write(io, outdata)
                    end
                catch
                    break
                end
            end
        catch
        end

        # Cleanup (inside GC.@preserve so ctx is alive during session_del)
        nghttp2_session_del(session_ptr)
        close(cb)
        try; close(io); catch; end
    end
end

# --- Server C callbacks ---

function _server_get_ctx(user_data::Ptr{Cvoid})::ServerContext
    return unsafe_pointer_to_objref(user_data)::ServerContext
end

function _server_on_header_cb(session_ptr::Ptr{Cvoid}, frame_ptr::Ptr{Cvoid},
                               name_ptr::Ptr{UInt8}, namelen::Csize_t,
                               value_ptr::Ptr{UInt8}, valuelen::Csize_t,
                               flags::UInt8, user_data::Ptr{Cvoid})::Cint
    try
        ctx = _server_get_ctx(user_data)
        stream_id = unsafe_load(Ptr{Int32}(frame_ptr + sizeof(Csize_t)))
        name = unsafe_string(name_ptr, namelen)
        value = unsafe_string(value_ptr, valuelen)
        lock(ctx.lock) do
            if !haskey(ctx.streams, stream_id)
                ctx.streams[stream_id] = ServerStreamState(stream_id)
            end
            st = ctx.streams[stream_id]
            if name == ":method"
                st.method = value
            elseif name == ":path"
                st.path = value
            else
                push!(st.headers, NVPair(name, value))
            end
        end
    catch
    end
    return Cint(0)
end

function _server_on_data_chunk_cb(session_ptr::Ptr{Cvoid}, flags::UInt8,
                                   stream_id::Int32, data_ptr::Ptr{UInt8},
                                   len::Csize_t, user_data::Ptr{Cvoid})::Cint
    try
        ctx = _server_get_ctx(user_data)
        chunk = copy(unsafe_wrap(Array, data_ptr, len; own=false))
        lock(ctx.lock) do
            if haskey(ctx.streams, stream_id)
                append!(ctx.streams[stream_id].body, chunk)
            end
        end
    catch
    end
    return Cint(0)
end

"""
on_frame_recv callback: dispatches handler when END_STREAM is received.
The nghttp2_frame struct layout: nghttp2_frame_hd (length:size_t, stream_id:int32, type:uint8, flags:uint8, ...)
"""
function _server_on_frame_recv_cb(session_ptr::Ptr{Cvoid}, frame_ptr::Ptr{Cvoid},
                                   user_data::Ptr{Cvoid})::Cint
    try
        ctx = _server_get_ctx(user_data)
        # Read frame header fields
        stream_id = unsafe_load(Ptr{Int32}(frame_ptr + sizeof(Csize_t)))
        frame_type = unsafe_load(Ptr{UInt8}(frame_ptr + sizeof(Csize_t) + 4))
        frame_flags = unsafe_load(Ptr{UInt8}(frame_ptr + sizeof(Csize_t) + 5))

        # Check if this frame has END_STREAM flag and is HEADERS or DATA
        has_end_stream = (frame_flags & NGHTTP2_FLAG_END_STREAM) != 0
        is_headers = frame_type == NGHTTP2_HEADERS
        is_data = frame_type == NGHTTP2_DATA

        if has_end_stream && (is_headers || is_data) && stream_id > 0
            st = lock(ctx.lock) do
                ss = get(ctx.streams, stream_id, nothing)
                if ss !== nothing
                    delete!(ctx.streams, stream_id)
                end
                ss
            end
            if st !== nothing && !isempty(st.method)
                # Dispatch to handler
                req = ServerRequest(st.method, st.path, st.headers, st.body, st.id)
                resp = try
                    ctx.handler(req)
                catch
                    ServerResponse(500, "Internal Server Error")
                end

                # Build response headers
                resp_headers = NVPair[NVPair(":status", string(resp.status))]
                append!(resp_headers, resp.headers)

                # Submit response
                nva = [to_nghttp2_nv(nv) for nv in resp_headers]
                GC.@preserve resp_headers nva begin
                    nghttp2_submit_response2(ctx.session_ptr, stream_id,
                                              pointer(nva), length(nva), C_NULL)
                end
            end
        end
    catch
    end
    return Cint(0)
end

_server_on_header_cb_ptr() = @cfunction(_server_on_header_cb, Cint,
    (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, Csize_t, Ptr{UInt8}, Csize_t, UInt8, Ptr{Cvoid}))
_server_on_data_chunk_cb_ptr() = @cfunction(_server_on_data_chunk_cb, Cint,
    (Ptr{Cvoid}, UInt8, Int32, Ptr{UInt8}, Csize_t, Ptr{Cvoid}))
_server_on_frame_recv_cb_ptr() = @cfunction(_server_on_frame_recv_cb, Cint,
    (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}))
