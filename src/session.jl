"""
    nghttp2_session_client_new(callbacks, user_data=C_NULL) → (Cint, Ptr{Cvoid})

Create a new client session. Returns `(error_code, session_ptr)`.
"""
function nghttp2_session_client_new(callbacks::Ptr{Cvoid}, user_data::Ptr{Cvoid}=C_NULL)
    session_ptr = Ref{Ptr{Cvoid}}(C_NULL)
    rv = ccall((:nghttp2_session_client_new, libnghttp2), Cint,
               (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{Cvoid}),
               session_ptr, callbacks, user_data)
    return (rv, session_ptr[])
end

"""
    nghttp2_session_server_new(callbacks, user_data=C_NULL) → (Cint, Ptr{Cvoid})

Create a new server session. Returns `(error_code, session_ptr)`.
"""
function nghttp2_session_server_new(callbacks::Ptr{Cvoid}, user_data::Ptr{Cvoid}=C_NULL)
    session_ptr = Ref{Ptr{Cvoid}}(C_NULL)
    rv = ccall((:nghttp2_session_server_new, libnghttp2), Cint,
               (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{Cvoid}),
               session_ptr, callbacks, user_data)
    return (rv, session_ptr[])
end

"""
    nghttp2_session_del(session)

Delete a session and free all associated resources.
"""
function nghttp2_session_del(session::Ptr{Cvoid})
    ccall((:nghttp2_session_del, libnghttp2), Cvoid, (Ptr{Cvoid},), session)
    return nothing
end

"""
    nghttp2_option_new() → (Cint, Ptr{Cvoid})

Create a new option object. Returns `(error_code, option_ptr)`.
"""
function nghttp2_option_new()
    option_ptr = Ref{Ptr{Cvoid}}(C_NULL)
    rv = ccall((:nghttp2_option_new, libnghttp2), Cint,
               (Ptr{Ptr{Cvoid}},), option_ptr)
    return (rv, option_ptr[])
end

"""
    nghttp2_option_del(option)

Free an option object.
"""
function nghttp2_option_del(option::Ptr{Cvoid})
    ccall((:nghttp2_option_del, libnghttp2), Cvoid, (Ptr{Cvoid},), option)
    return nothing
end

"""
    nghttp2_option_set_no_auto_window_update(option, val)

Set the no-auto-window-update option.
"""
function nghttp2_option_set_no_auto_window_update(option::Ptr{Cvoid}, val::Integer)
    ccall((:nghttp2_option_set_no_auto_window_update, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Cint), option, val)
    return nothing
end

"""
    nghttp2_option_set_peer_max_concurrent_streams(option, val)

Set the peer max concurrent streams option.
"""
function nghttp2_option_set_peer_max_concurrent_streams(option::Ptr{Cvoid}, val::Integer)
    ccall((:nghttp2_option_set_peer_max_concurrent_streams, libnghttp2), Cvoid,
          (Ptr{Cvoid}, UInt32), option, val)
    return nothing
end

# --- Session I/O ---

"""
    nghttp2_session_mem_send2(session) → (Cssize_t, Ptr{UInt8})

Serialize outgoing data from the session into memory.
Returns `(nbytes, data_ptr)` where `nbytes` is the number of bytes
serialized and `data_ptr` points to the serialized data.
"""
function nghttp2_session_mem_send2(session::Ptr{Cvoid})
    data_ptr = Ref{Ptr{UInt8}}(Ptr{UInt8}(0))
    rv = ccall((:nghttp2_session_mem_send2, libnghttp2), Cssize_t,
               (Ptr{Cvoid}, Ptr{Ptr{UInt8}}), session, data_ptr)
    return (rv, data_ptr[])
end

"""
    nghttp2_session_mem_recv2(session, data::Vector{UInt8}) → Cssize_t

Process incoming data. Returns the number of bytes processed.
"""
function nghttp2_session_mem_recv2(session::Ptr{Cvoid}, data::Vector{UInt8})
    ccall((:nghttp2_session_mem_recv2, libnghttp2), Cssize_t,
          (Ptr{Cvoid}, Ptr{UInt8}, Csize_t), session, data, length(data))
end

"""
    nghttp2_session_want_read(session) → Bool

Return `true` if the session wants to receive data from the remote peer.
"""
function nghttp2_session_want_read(session::Ptr{Cvoid})
    rv = ccall((:nghttp2_session_want_read, libnghttp2), Cint, (Ptr{Cvoid},), session)
    return rv != 0
end

"""
    nghttp2_session_want_write(session) → Bool

Return `true` if the session wants to send data to the remote peer.
"""
function nghttp2_session_want_write(session::Ptr{Cvoid})
    rv = ccall((:nghttp2_session_want_write, libnghttp2), Cint, (Ptr{Cvoid},), session)
    return rv != 0
end
