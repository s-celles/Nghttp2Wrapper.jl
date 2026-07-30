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
Response body source passed to nghttp2 via `nghttp2_data_provider`.

`data` holds the full response body bytes; `offset` is the next
byte to read. The data source read callback copies up to `len`
bytes into nghttp2's buffer on each invocation, advances `offset`,
and signals `NGHTTP2_DATA_FLAG_EOF` when `offset` reaches
`length(data)`.

The struct is kept alive across the C boundary by storing it in
the owning `ServerContext`'s `response_bodies` dict (so GC does
not reclaim it while nghttp2 still holds a pointer). The dict
entry is removed when the callback signals EOF.
"""
mutable struct ResponseBodySource
    data::Vector{UInt8}
    offset::Int
    # Trailers to emit once the body is exhausted. When non-empty the body must
    # not carry END_STREAM — the trailing HEADERS block closes the stream
    # instead (RFC 7540 §8.1).
    trailers::Vector{NVPair}
end

ResponseBodySource(body::Vector{UInt8}) = ResponseBodySource(body, 0, NVPair[])
ResponseBodySource(body::Vector{UInt8}, trailers::Vector{NVPair}) =
    ResponseBodySource(body, 0, trailers)

"""
Internal context for server-side nghttp2 callbacks.
"""
mutable struct ServerContext
    streams::Dict{Int32,ServerStreamState}
    handler::Function
    session_ptr::Ptr{Cvoid}
    io_stream::IO
    lock::ReentrantLock
    # Pinned response body sources keyed by stream ID. Entries are
    # created in `_server_on_frame_recv_cb` before calling
    # `nghttp2_submit_response2` with a data provider, and removed in
    # `_server_data_source_read_cb` once EOF is reached. This dict is
    # the GC root that keeps `ResponseBodySource` alive while nghttp2
    # holds a pointer to it via `nghttp2_data_source.ptr`.
    response_bodies::Dict{Int32,ResponseBodySource}
end

"""
    HTTP2Server(handler, port; host="0.0.0.0", certfile="", keyfile="")

Create an HTTP/2 server listening on the given port.
If `certfile` and `keyfile` are provided, the server uses TLS with ALPN `h2`.
Otherwise it uses cleartext HTTP/2 (h2c).

The handler function receives a `ServerRequest` and returns a `ServerResponse`.

# Examples

Cleartext (h2c):
```julia
server = HTTP2Server(8080) do req
    ServerResponse(200, "Hello HTTP/2!")
end
```

TLS (h2):
```julia
server = HTTP2Server(8443; certfile="cert.pem", keyfile="key.pem") do req
    ServerResponse(200, "Hello HTTPS/2!")
end
```
"""
mutable struct HTTP2Server
    listener::Any  # Sockets.TCPServer (h2c) or Reseau.TLS.Listener (h2)
    handler::Function
    tls_config::Any  # Reseau.TLS.Config or nothing
    connections::Vector{Task}
    isopen::Bool
    accept_task::Task

    function HTTP2Server(handler::Function, port::Integer;
                         host::AbstractString="0.0.0.0",
                         certfile::AbstractString="",
                         keyfile::AbstractString="")
        tls_config = nothing
        listener = if !isempty(certfile) && !isempty(keyfile)
            tls_config = TLS.Config(
                cert_file = certfile,
                key_file = keyfile,
                alpn_protocols = ["h2"],
            )
            TLS.listen("tcp", "$(host):$(port)", tls_config)
        else
            Sockets.listen(Sockets.InetAddr(host, port))
        end

        server = new(listener, handler, tls_config, Task[], true, Task(() -> nothing))
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

"""
    listener_port(server::HTTP2Server) -> Int

Return the TCP port the server's listening socket is bound to. Works for
both plaintext (h2c) and TLS (h2) listeners.
"""
function listener_port(server::HTTP2Server)
    l = server.listener
    if l isa TLS.Listener
        return Int(TLS.addr(l).port)
    else
        return Int(Sockets.getsockname(l)[2])
    end
end

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
            io = try
                if server.tls_config !== nothing
                    TLS.accept(server.listener)
                else
                    accept(server.listener)
                end
            catch
                break
            end

            # Spawn connection handler
            t = Threads.@spawn _server_connection_handler(server, io)
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
        ReentrantLock(),
        Dict{Int32,ResponseBodySource}(),
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

    # I/O loop — read data from client and feed to nghttp2.
    # Reseau's TLS.Conn doesn't support single-byte read, so we use unsafe_read
    # for exact-length reads (like the client does). For plain TCP we use the
    # byte-read pattern to avoid busy waiting.
    # GC.@preserve ensures ctx stays alive while C code holds a pointer to it.
    is_tls = io isa TLS.Conn
    GC.@preserve ctx begin
        buf = Vector{UInt8}(undef, 65536)
        try
            while server.isopen && isopen(io)
                nbytes = if is_tls
                    # Read HTTP/2 frame: 9-byte header + variable payload.
                    # nghttp2 handles the client connection preface (24-byte
                    # magic) + SETTINGS frame as a single initial chunk, so
                    # we need to read the preface bytes first then frames.
                    _read_tls_chunk!(io, buf)
                else
                    _read_tcp_chunk!(io, buf)
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

"""
Read one chunk from a plain TCP socket: at least one byte, then drain
whatever else is immediately available.
"""
function _read_tcp_chunk!(io, buf::Vector{UInt8})
    try
        buf[1] = read(io, UInt8)
        avail = bytesavailable(io)
        if avail > 0
            extra = min(avail, length(buf) - 1)
            unsafe_read(io, pointer(buf, 2), UInt(extra))
            return 1 + Int(extra)
        end
        return 1
    catch
        return 0
    end
end

"""
Read one chunk from a TLS connection: either the initial client connection preface
(24 bytes) and a following frame, or a single HTTP/2 frame (9-byte header +
variable payload).
"""
const HTTP2_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
const HTTP2_PREFACE_LEN = length(HTTP2_PREFACE)

function _read_tls_chunk!(io, buf::Vector{UInt8})
    # First call: peek at 3 bytes. If they match "PRI", this is the connection
    # preface — read it in full first, then read one frame.
    try
        # Read 9 bytes (enough to hold either 9 bytes of preface or a frame header)
        unsafe_read(io, pointer(buf), UInt(9))

        # Is this the start of the preface?
        if buf[1] == UInt8('P') && buf[2] == UInt8('R') && buf[3] == UInt8('I')
            # Read the rest of the preface (24 - 9 = 15 more bytes)
            unsafe_read(io, pointer(buf, 10), UInt(HTTP2_PREFACE_LEN - 9))
            return HTTP2_PREFACE_LEN
        end

        # It's a frame header — parse length and read payload
        frame_len = (UInt32(buf[1]) << 16) | (UInt32(buf[2]) << 8) | UInt32(buf[3])
        total_len = Int(9 + frame_len)
        if frame_len > 0
            if total_len > length(buf)
                resize!(buf, total_len)
            end
            unsafe_read(io, pointer(buf, 10), UInt(frame_len))
        end
        return total_len
    catch
        return 0
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

                # Submit response. If the handler returned a non-empty
                # body, build an nghttp2_data_provider that streams the
                # body via the C callback defined below. The
                # ResponseBodySource is pinned in ctx.response_bodies so
                # it survives GC while nghttp2 holds a pointer to it.
                nva = [to_nghttp2_nv(nv) for nv in resp_headers]
                # A trailers-only response still needs a data provider: with a
                # C_NULL provider nghttp2 puts END_STREAM on the HEADERS frame
                # and there is no longer any point at which trailers can follow.
                if isempty(resp.body) && isempty(resp.trailers)
                    GC.@preserve resp_headers nva begin
                        nghttp2_submit_response2(ctx.session_ptr, stream_id,
                                                  pointer(nva), length(nva), C_NULL)
                    end
                else
                    body_source = ResponseBodySource(resp.body, resp.trailers)
                    lock(ctx.lock) do
                        ctx.response_bodies[stream_id] = body_source
                    end
                    data_prd = Ref(Nghttp2DataProvider(
                        pointer_from_objref(body_source),
                        _server_data_source_read_cb_ptr(),
                    ))
                    GC.@preserve resp_headers nva body_source data_prd begin
                        nghttp2_submit_response2(ctx.session_ptr, stream_id,
                                                  pointer(nva), length(nva),
                                                  Base.unsafe_convert(Ptr{Cvoid}, data_prd))
                    end
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

"""
Layout-compatible representation of nghttp2's `nghttp2_data_provider`:

```c
typedef union {
    int fd;
    void *ptr;
} nghttp2_data_source;

typedef struct {
    nghttp2_data_source source;
    nghttp2_data_source_read_callback read_callback;
} nghttp2_data_provider;
```

We only use the `ptr` variant of the union, so a single
`Ptr{Cvoid}` for `source` matches the 8-byte union width on
64-bit platforms.
"""
struct Nghttp2DataProvider
    source::Ptr{Cvoid}
    read_callback::Ptr{Cvoid}
end

"""
nghttp2 data source read callback.

Copies up to `len` bytes from the `ResponseBodySource` (whose
Julia pointer is carried in the `source` union) into the output
buffer that nghttp2 provides. Advances the source's offset, and
sets `NGHTTP2_DATA_FLAG_EOF` in `data_flags` once the whole body
has been consumed.

Matches the C signature:

```c
ssize_t (*nghttp2_data_source_read_callback)(
    nghttp2_session *session, int32_t stream_id, uint8_t *buf,
    size_t length, uint32_t *data_flags, nghttp2_data_source *source,
    void *user_data);
```
"""
function _server_data_source_read_cb(session_ptr::Ptr{Cvoid}, stream_id::Int32,
                                      buf::Ptr{UInt8}, len::Csize_t,
                                      data_flags::Ptr{UInt32},
                                      source::Ptr{Cvoid},
                                      user_data::Ptr{Cvoid})::Cssize_t
    try
        # `source` points at an `nghttp2_data_source` union. We stored
        # the Julia pointer in the `ptr` field, so dereference one
        # pointer level to read our `ResponseBodySource` back.
        src_ptr = unsafe_load(Ptr{Ptr{Cvoid}}(source))
        body_source = unsafe_pointer_to_objref(src_ptr)::ResponseBodySource

        remaining = length(body_source.data) - body_source.offset
        to_copy = min(Int(len), remaining)
        if to_copy > 0
            GC.@preserve body_source unsafe_copyto!(
                buf, pointer(body_source.data, body_source.offset + 1), to_copy)
            body_source.offset += to_copy
        end

        if body_source.offset >= length(body_source.data)
            # Signal end-of-data. We must OR with the existing flags because
            # nghttp2 may have set NGHTTP2_DATA_FLAG_NO_COPY or similar.
            #
            # With trailers pending, add NGHTTP2_DATA_FLAG_NO_END_STREAM so the
            # last DATA frame does *not* close the stream, then submit the
            # trailing HEADERS block, which does. Submitting from inside this
            # callback is the pattern nghttp2 documents for trailers.
            flags = unsafe_load(data_flags) | NGHTTP2_DATA_FLAG_EOF
            if !isempty(body_source.trailers)
                flags |= NGHTTP2_DATA_FLAG_NO_END_STREAM
            end
            unsafe_store!(data_flags, flags)

            if !isempty(body_source.trailers)
                nghttp2_submit_trailer(session_ptr, stream_id, body_source.trailers)
            end

            # Release the pinned body source so the dict doesn't leak
            # across many responses on the same connection. The ctx
            # pointer is in user_data (set via nghttp2_session_server_new).
            try
                ctx = _server_get_ctx(user_data)
                lock(ctx.lock) do
                    delete!(ctx.response_bodies, stream_id)
                end
            catch
                # If ctx retrieval fails we still return the data we
                # already copied; the leak is bounded by the connection
                # lifetime.
            end
        end

        return Cssize_t(to_copy)
    catch
        return Cssize_t(NGHTTP2_ERR_CALLBACK_FAILURE)
    end
end

_server_data_source_read_cb_ptr() = @cfunction(_server_data_source_read_cb, Cssize_t,
    (Ptr{Cvoid}, Int32, Ptr{UInt8}, Csize_t, Ptr{UInt32}, Ptr{Cvoid}, Ptr{Cvoid}))
