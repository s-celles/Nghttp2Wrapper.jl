"""
Internal stream state tracking for an active HTTP/2 stream.
"""
mutable struct StreamState
    id::Int32
    headers::Vector{NVPair}
    body::Vector{UInt8}
    status::Int
    done::Channel{Response}
    streaming::Bool
    chunks::Channel{Vector{UInt8}}
end

function StreamState(id::Int32; streaming::Bool=false)
    StreamState(id, NVPair[], UInt8[], 0,
                Channel{Response}(1),
                streaming,
                Channel{Vector{UInt8}}(32))
end

"""
Internal context passed as user_data to nghttp2 callbacks.
"""
mutable struct ClientContext
    streams::Dict{Int32,StreamState}
    lock::ReentrantLock
end

"""
    HTTP2Client(host; port=443, max_concurrent_streams=100,
                initial_window_size=65535, header_table_size=4096,
                verify_peer=true)

Create an HTTP/2 client connected to the given host over TLS.
The connection is established immediately with ALPN negotiation for h2.
"""
mutable struct HTTP2Client
    session_ptr::Ptr{Cvoid}
    callbacks::Callbacks
    tls_stream::Any
    tcp_socket::Sockets.TCPSocket
    host::String
    port::Int
    ctx::ClientContext
    ctx_ref::Ref{ClientContext}
    io_task::Task
    isopen::Bool

    function HTTP2Client(host::AbstractString; port::Integer=443,
                         max_concurrent_streams::Integer=100,
                         initial_window_size::Integer=65535,
                         header_table_size::Integer=4096,
                         verify_peer::Bool=true)
        # TCP connect
        tcp = Sockets.connect(host, port)

        # TLS setup with ALPN
        ssl_ctx = OpenSSL.SSLContext(OpenSSL.TLSClientMethod())
        OpenSSL.ssl_set_options(ssl_ctx, OpenSSL.SSL_OP_NO_SSLv3)
        OpenSSL.ssl_set_alpn(ssl_ctx, OpenSSL.UPDATE_HTTP2_ALPN)
        tls = OpenSSL.SSLStream(ssl_ctx, tcp)
        OpenSSL.hostname!(tls, host)
        OpenSSL.connect(tls; require_ssl_verification=verify_peer)

        # Create context for callbacks
        ctx = ClientContext(Dict{Int32,StreamState}(), ReentrantLock())
        ctx_ref = Ref(ctx)

        # Create callbacks with C function pointers
        cb = Callbacks()
        nghttp2_session_callbacks_set_on_header_callback(cb.ptr, _on_header_cb_ptr())
        nghttp2_session_callbacks_set_on_data_chunk_recv_callback(cb.ptr, _on_data_chunk_cb_ptr())
        nghttp2_session_callbacks_set_on_stream_close_callback(cb.ptr, _on_stream_close_cb_ptr())

        # Create raw session with user_data pointing to context
        rv, session_ptr = nghttp2_session_client_new(cb.ptr, pointer_from_objref(ctx_ref))
        check_error(rv)

        # Submit settings
        settings_entries = Nghttp2SettingsEntry[]
        if max_concurrent_streams != 100
            push!(settings_entries, Nghttp2SettingsEntry(NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS, UInt32(max_concurrent_streams)))
        end
        if initial_window_size != 65535
            push!(settings_entries, Nghttp2SettingsEntry(NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE, UInt32(initial_window_size)))
        end
        if header_table_size != 4096
            push!(settings_entries, Nghttp2SettingsEntry(NGHTTP2_SETTINGS_HEADER_TABLE_SIZE, UInt32(header_table_size)))
        end
        if isempty(settings_entries)
            nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE,
                                     Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
        else
            nghttp2_submit_settings(session_ptr, NGHTTP2_FLAG_NONE, settings_entries)
        end

        # Send connection preface + settings
        outdata = _session_send_all(session_ptr)
        write(tls, outdata)

        client = new(session_ptr, cb, tls, tcp, String(host), Int(port),
                     ctx, ctx_ref, Task(() -> nothing), true)

        # Start I/O loop
        client.io_task = @async _io_loop(client)

        finalizer(client) do obj
            if obj.isopen
                obj.isopen = false
                if obj.session_ptr != C_NULL
                    nghttp2_session_del(obj.session_ptr)
                    obj.session_ptr = C_NULL
                end
                try; close(obj.tls_stream); catch; end
                try; close(obj.tcp_socket); catch; end
            end
        end

        return client
    end
end

"""Send all pending data from the session."""
function _session_send_all(session_ptr::Ptr{Cvoid})
    result = UInt8[]
    while true
        nbytes, data_ptr = nghttp2_session_mem_send2(session_ptr)
        if nbytes <= 0
            break
        end
        append!(result, unsafe_wrap(Array, data_ptr, nbytes; own=false))
    end
    return result
end

function Base.close(client::HTTP2Client)
    if client.isopen
        client.isopen = false
        if client.session_ptr != C_NULL
            nghttp2_session_del(client.session_ptr)
            client.session_ptr = C_NULL
        end
        try; close(client.tls_stream); catch; end
        try; close(client.tcp_socket); catch; end
    end
    return nothing
end

Base.isopen(client::HTTP2Client) = client.isopen

function Base.show(io::IO, client::HTTP2Client)
    state = client.isopen ? "open" : "closed"
    print(io, "HTTP2Client(\"$(client.host):$(client.port)\", $(state))")
end

# --- C callback functions (no closures — use user_data to access context) ---

function _get_ctx(user_data::Ptr{Cvoid})::ClientContext
    ref = unsafe_pointer_to_objref(Ptr{Ref{ClientContext}}(user_data))
    return ref[]
end

function _on_header_cb(session_ptr::Ptr{Cvoid}, frame_ptr::Ptr{Cvoid},
                       name_ptr::Ptr{UInt8}, namelen::Csize_t,
                       value_ptr::Ptr{UInt8}, valuelen::Csize_t,
                       flags::UInt8, user_data::Ptr{Cvoid})::Cint
    try
        ctx = _get_ctx(user_data)
        # nghttp2_frame_hd layout: length(size_t=8 bytes) + stream_id(int32=4 bytes)
        stream_id = unsafe_load(Ptr{Int32}(frame_ptr + sizeof(Csize_t)))
        name = unsafe_string(name_ptr, namelen)
        value = unsafe_string(value_ptr, valuelen)
        lock(ctx.lock) do
            if haskey(ctx.streams, stream_id)
                st = ctx.streams[stream_id]
                if name == ":status"
                    st.status = parse(Int, value)
                else
                    push!(st.headers, NVPair(name, value))
                end
            end
        end
    catch
    end
    return Cint(0)
end

function _on_data_chunk_cb(session_ptr::Ptr{Cvoid}, flags::UInt8,
                            stream_id::Int32, data_ptr::Ptr{UInt8},
                            len::Csize_t, user_data::Ptr{Cvoid})::Cint
    try
        ctx = _get_ctx(user_data)
        chunk = copy(unsafe_wrap(Array, data_ptr, len; own=false))
        lock(ctx.lock) do
            if haskey(ctx.streams, stream_id)
                st = ctx.streams[stream_id]
                if st.streaming
                    try; put!(st.chunks, chunk); catch; end
                else
                    append!(st.body, chunk)
                end
            end
        end
    catch
    end
    return Cint(0)
end

function _on_stream_close_cb(session_ptr::Ptr{Cvoid}, stream_id::Int32,
                              error_code::UInt32, user_data::Ptr{Cvoid})::Cint
    try
        ctx = _get_ctx(user_data)
        lock(ctx.lock) do
            if haskey(ctx.streams, stream_id)
                st = ctx.streams[stream_id]
                if st.streaming
                    try; close(st.chunks); catch; end
                end
                resp = Response(st.status, st.headers, st.body)
                try; put!(st.done, resp); catch; end
                delete!(ctx.streams, stream_id)
            end
        end
    catch
    end
    return Cint(0)
end

# Pre-compiled C function pointers
_on_header_cb_ptr() = @cfunction(_on_header_cb, Cint,
    (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, Csize_t, Ptr{UInt8}, Csize_t, UInt8, Ptr{Cvoid}))
_on_data_chunk_cb_ptr() = @cfunction(_on_data_chunk_cb, Cint,
    (Ptr{Cvoid}, UInt8, Int32, Ptr{UInt8}, Csize_t, Ptr{Cvoid}))
_on_stream_close_cb_ptr() = @cfunction(_on_stream_close_cb, Cint,
    (Ptr{Cvoid}, Int32, UInt32, Ptr{Cvoid}))

# --- I/O Loop ---

function _io_loop(client::HTTP2Client)
    buf = Vector{UInt8}(undef, 65536)
    try
        while client.isopen && isopen(client.tcp_socket)
            # Read frame header (9 bytes)
            try
                unsafe_read(client.tls_stream, pointer(buf), UInt(9))
            catch
                break
            end

            # Parse frame length
            frame_len = (UInt32(buf[1]) << 16) | (UInt32(buf[2]) << 8) | UInt32(buf[3])
            total_len = Int(9 + frame_len)

            # Read frame payload
            if frame_len > 0
                if total_len > length(buf)
                    resize!(buf, total_len)
                end
                try
                    unsafe_read(client.tls_stream, pointer(buf, 10), UInt(frame_len))
                catch
                    break
                end
            end

            # Feed complete frame to session
            try
                nghttp2_session_mem_recv2(client.session_ptr, buf[1:total_len])
            catch
                break
            end

            # Send any pending outgoing data
            try
                outdata = _session_send_all(client.session_ptr)
                if !isempty(outdata)
                    write(client.tls_stream, outdata)
                end
            catch
                break
            end
        end
    catch
    end
    client.isopen = false

    # Close any pending streams
    lock(client.ctx.lock) do
        for (sid, st) in client.ctx.streams
            resp = Response(0, NVPair[], UInt8[])
            try; put!(st.done, resp); catch; end
            if st.streaming
                try; close(st.chunks); catch; end
            end
        end
        empty!(client.ctx.streams)
    end
end
