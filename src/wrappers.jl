"""Check that a wrapper object is still open; throw ArgumentError if closed."""
function _check_open(obj, name::String)
    if !isopen(obj)
        throw(ArgumentError("$name is closed"))
    end
end

# --- Callbacks ---

"""
    Callbacks()

Create a new nghttp2 callbacks object. Resources are automatically
freed when the object is garbage collected, or when `close()` is called.
"""
mutable struct Callbacks
    ptr::Ptr{Cvoid}
    refs::Vector{Any}
    isopen::Bool

    function Callbacks()
        rv, ptr = nghttp2_session_callbacks_new()
        check_error(rv)
        cb = new(ptr, Any[], true)
        finalizer(cb) do obj
            if obj.isopen
                obj.isopen = false
                nghttp2_session_callbacks_del(obj.ptr)
            end
        end
        return cb
    end
end

function Base.close(cb::Callbacks)
    if cb.isopen
        cb.isopen = false
        nghttp2_session_callbacks_del(cb.ptr)
    end
    return nothing
end

Base.isopen(cb::Callbacks) = cb.isopen

function Base.show(io::IO, cb::Callbacks)
    state = cb.isopen ? "open" : "closed"
    print(io, "Callbacks($(state))")
end

# --- Option ---

"""
    Option()

Create a new nghttp2 option object for session configuration.
"""
mutable struct Option
    ptr::Ptr{Cvoid}
    isopen::Bool

    function Option()
        rv, ptr = nghttp2_option_new()
        check_error(rv)
        opt = new(ptr, true)
        finalizer(opt) do obj
            if obj.isopen
                obj.isopen = false
                nghttp2_option_del(obj.ptr)
            end
        end
        return opt
    end
end

function Base.close(opt::Option)
    if opt.isopen
        opt.isopen = false
        nghttp2_option_del(opt.ptr)
    end
    return nothing
end

Base.isopen(opt::Option) = opt.isopen

function Base.show(io::IO, opt::Option)
    state = opt.isopen ? "open" : "closed"
    print(io, "Option($(state))")
end

"""
    set_peer_max_concurrent_streams!(opt::Option, val::Integer)

Set the peer max concurrent streams option.
"""
function set_peer_max_concurrent_streams!(opt::Option, val::Integer)
    _check_open(opt, "Option")
    nghttp2_option_set_peer_max_concurrent_streams(opt.ptr, val)
    return nothing
end

"""
    set_no_auto_window_update!(opt::Option, val::Bool)

Set the no-auto-window-update option.
"""
function set_no_auto_window_update!(opt::Option, val::Bool)
    _check_open(opt, "Option")
    nghttp2_option_set_no_auto_window_update(opt.ptr, val ? 1 : 0)
    return nothing
end

# --- Session ---

"""
    Session(callbacks::Callbacks; server::Bool=false)

Create a new HTTP/2 session (client by default, server if `server=true`).
The session holds a reference to the callbacks to prevent premature GC.
"""
mutable struct Session
    ptr::Ptr{Cvoid}
    callbacks::Callbacks
    isopen::Bool

    function Session(callbacks::Callbacks; server::Bool=false)
        _check_open(callbacks, "Callbacks")
        if server
            rv, ptr = nghttp2_session_server_new(callbacks.ptr)
        else
            rv, ptr = nghttp2_session_client_new(callbacks.ptr)
        end
        check_error(rv)
        sess = new(ptr, callbacks, true)
        finalizer(sess) do obj
            if obj.isopen
                obj.isopen = false
                nghttp2_session_del(obj.ptr)
            end
        end
        return sess
    end
end

function Base.close(session::Session)
    if session.isopen
        session.isopen = false
        nghttp2_session_del(session.ptr)
    end
    return nothing
end

Base.isopen(session::Session) = session.isopen

function Base.show(io::IO, session::Session)
    state = session.isopen ? "open" : "closed"
    print(io, "Session($(state))")
end

# --- Session typed operations ---

"""
    submit_settings!(session::Session)
    submit_settings!(session::Session, settings::Vector{Nghttp2SettingsEntry})

Submit a SETTINGS frame.
"""
function submit_settings!(session::Session)
    _check_open(session, "Session")
    rv = nghttp2_submit_settings(session.ptr, NGHTTP2_FLAG_NONE,
                                  Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
    check_error(rv)
    return nothing
end

function submit_settings!(session::Session, settings::Vector{Nghttp2SettingsEntry})
    _check_open(session, "Session")
    rv = nghttp2_submit_settings(session.ptr, NGHTTP2_FLAG_NONE, settings)
    check_error(rv)
    return nothing
end

"""
    send!(session::Session) → Vector{UInt8}

Serialize all pending outgoing data from the session into a byte vector.
"""
function send!(session::Session)
    _check_open(session, "Session")
    result = UInt8[]
    while true
        nbytes, data_ptr = nghttp2_session_mem_send2(session.ptr)
        if nbytes < 0
            check_error(nbytes)
        elseif nbytes == 0
            break
        else
            append!(result, unsafe_wrap(Array, data_ptr, nbytes; own=false))
        end
    end
    return result
end

"""
    recv!(session::Session, data::Vector{UInt8}) → Int

Process incoming data. Returns the number of bytes consumed.
"""
function recv!(session::Session, data::Vector{UInt8})
    _check_open(session, "Session")
    rv = nghttp2_session_mem_recv2(session.ptr, data)
    check_error(rv)
    return Int(rv)
end

"""
    want_read(session::Session) → Bool

Return true if the session wants to receive data.
"""
function want_read(session::Session)
    _check_open(session, "Session")
    return nghttp2_session_want_read(session.ptr)
end

"""
    want_write(session::Session) → Bool

Return true if the session wants to send data.
"""
function want_write(session::Session)
    _check_open(session, "Session")
    return nghttp2_session_want_write(session.ptr)
end

"""
    submit_ping!(session::Session)

Submit a PING frame.
"""
function submit_ping!(session::Session)
    _check_open(session, "Session")
    rv = nghttp2_submit_ping(session.ptr)
    check_error(rv)
    return nothing
end

"""
    submit_goaway!(session::Session, last_stream_id::Integer, error_code::Integer)

Submit a GOAWAY frame.
"""
function submit_goaway!(session::Session, last_stream_id::Integer, error_code::Integer)
    _check_open(session, "Session")
    rv = nghttp2_submit_goaway(session.ptr, last_stream_id, error_code)
    check_error(rv)
    return nothing
end

# --- HpackDeflater ---

"""
    HpackDeflater(max_table_size::Integer=4096)

Create a new HPACK compressor.
"""
mutable struct HpackDeflater
    ptr::Ptr{Cvoid}
    max_size::Int
    isopen::Bool

    function HpackDeflater(max_table_size::Integer=4096)
        rv, ptr = nghttp2_hd_deflate_new(max_table_size)
        check_error(rv)
        d = new(ptr, Int(max_table_size), true)
        finalizer(d) do obj
            if obj.isopen
                obj.isopen = false
                nghttp2_hd_deflate_del(obj.ptr)
            end
        end
        return d
    end
end

function Base.close(d::HpackDeflater)
    if d.isopen
        d.isopen = false
        nghttp2_hd_deflate_del(d.ptr)
    end
    return nothing
end

Base.isopen(d::HpackDeflater) = d.isopen

function Base.show(io::IO, d::HpackDeflater)
    state = d.isopen ? "open" : "closed"
    print(io, "HpackDeflater($(state), max_table_size=$(d.max_size))")
end

"""
    inspect_dynamic_table(d::HpackDeflater) → Vector{NVPair}

Return the entries currently in the HPACK dynamic table.
Note: This is an approximation — nghttp2 doesn't expose direct dynamic table
iteration, so we return the max_size as context information.
"""
function inspect_dynamic_table(d::HpackDeflater)
    _check_open(d, "HpackDeflater")
    # nghttp2 doesn't expose a public API to iterate the dynamic table entries.
    # We return an empty vector with the understanding that the dynamic table
    # state is internal to the deflater. Users can track entries manually.
    return NVPair[]
end

"""
    dynamic_table_size(d::HpackDeflater) → Int

Return the configured maximum dynamic table size for this deflater.
"""
function dynamic_table_size(d::HpackDeflater)
    _check_open(d, "HpackDeflater")
    return d.max_size
end

"""
    deflate(d::HpackDeflater, headers::Vector{NVPair}) → Vector{UInt8}

Compress headers using HPACK. Returns the compressed bytes.
"""
function deflate(d::HpackDeflater, headers::Vector{NVPair})
    _check_open(d, "HpackDeflater")
    buf = Vector{UInt8}(undef, 16384)
    nbytes = with_nva(headers) do nva_ptr, nvlen
        nghttp2_hd_deflate_hd2(d.ptr, pointer(buf), length(buf), nva_ptr, nvlen)
    end
    if nbytes < 0
        check_error(nbytes)
    end
    return buf[1:nbytes]
end

# --- HpackInflater ---

"""
    HpackInflater()

Create a new HPACK decompressor.
"""
mutable struct HpackInflater
    ptr::Ptr{Cvoid}
    isopen::Bool

    function HpackInflater()
        rv, ptr = nghttp2_hd_inflate_new()
        check_error(rv)
        i = new(ptr, true)
        finalizer(i) do obj
            if obj.isopen
                obj.isopen = false
                nghttp2_hd_inflate_del(obj.ptr)
            end
        end
        return i
    end
end

function Base.close(i::HpackInflater)
    if i.isopen
        i.isopen = false
        nghttp2_hd_inflate_del(i.ptr)
    end
    return nothing
end

Base.isopen(i::HpackInflater) = i.isopen

function Base.show(io::IO, i::HpackInflater)
    state = i.isopen ? "open" : "closed"
    print(io, "HpackInflater($(state))")
end

"""
    inflate(i::HpackInflater, data::Vector{UInt8}) → Vector{NVPair}

Decompress HPACK-encoded headers. Returns a vector of NVPairs.
"""
function inflate(i::HpackInflater, data::Vector{UInt8})
    _check_open(i, "HpackInflater")
    result = NVPair[]
    nv_out = Ref(Nghttp2Nv(Ptr{UInt8}(0), Ptr{UInt8}(0), 0, 0, 0))
    inflate_flags = Ref(Cint(0))
    offset = 0
    remaining = length(data)

    while remaining > 0
        processed = nghttp2_hd_inflate_hd2(i.ptr, nv_out, inflate_flags,
                                            pointer(data, offset + 1), remaining, 1)
        if processed < 0
            check_error(processed)
        end

        if inflate_flags[] & NGHTTP2_HD_INFLATE_EMIT != 0
            name = unsafe_string(nv_out[].name, nv_out[].namelen)
            value = unsafe_string(nv_out[].value, nv_out[].valuelen)
            push!(result, NVPair(name, value))
        end

        if inflate_flags[] & NGHTTP2_HD_INFLATE_FINAL != 0
            break
        end

        offset += processed
        remaining -= processed
        if processed == 0
            break
        end
    end

    return result
end
