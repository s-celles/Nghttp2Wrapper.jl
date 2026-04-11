"""
    nghttp2_session_callbacks_new() → (Cint, Ptr{Cvoid})

Allocate a new callbacks object. Returns `(error_code, callbacks_ptr)`.
"""
function nghttp2_session_callbacks_new()
    callbacks_ptr = Ref{Ptr{Cvoid}}(C_NULL)
    rv = ccall((:nghttp2_session_callbacks_new, libnghttp2), Cint,
               (Ptr{Ptr{Cvoid}},), callbacks_ptr)
    return (rv, callbacks_ptr[])
end

"""
    nghttp2_session_callbacks_del(callbacks)

Free a callbacks object.
"""
function nghttp2_session_callbacks_del(callbacks::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_del, libnghttp2), Cvoid,
          (Ptr{Cvoid},), callbacks)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks, cb)

Set the callback invoked when a frame is received.
"""
function nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_frame_recv_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback(callbacks, cb)

Set the callback invoked when a DATA frame chunk is received.
"""
function nghttp2_session_callbacks_set_on_data_chunk_recv_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_data_chunk_recv_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_stream_close_callback(callbacks, cb)

Set the callback invoked when a stream is closed.
"""
function nghttp2_session_callbacks_set_on_stream_close_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_stream_close_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_header_callback(callbacks, cb)

Set the callback invoked when a header name/value pair is received.
"""
function nghttp2_session_callbacks_set_on_header_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_header_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_begin_headers_callback(callbacks, cb)

Set the callback invoked when reception of a header block begins.
"""
function nghttp2_session_callbacks_set_on_begin_headers_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_begin_headers_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_before_frame_send_callback(callbacks, cb)

Set the callback invoked before a frame is sent.
"""
function nghttp2_session_callbacks_set_before_frame_send_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_before_frame_send_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_frame_send_callback(callbacks, cb)

Set the callback invoked after a frame is sent.
"""
function nghttp2_session_callbacks_set_on_frame_send_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_frame_send_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_on_frame_not_send_callback(callbacks, cb)

Set the callback invoked when a frame cannot be sent.
"""
function nghttp2_session_callbacks_set_on_frame_not_send_callback(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_on_frame_not_send_callback, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_send_callback2(callbacks, cb)

Set the send callback (v2 variant using nghttp2_ssize).
"""
function nghttp2_session_callbacks_set_send_callback2(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_send_callback2, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_recv_callback2(callbacks, cb)

Set the recv callback (v2 variant using nghttp2_ssize).
"""
function nghttp2_session_callbacks_set_recv_callback2(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_recv_callback2, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end

"""
    nghttp2_session_callbacks_set_error_callback2(callbacks, cb)

Set the error callback (v2 variant).
"""
function nghttp2_session_callbacks_set_error_callback2(callbacks::Ptr{Cvoid}, cb::Ptr{Cvoid})
    ccall((:nghttp2_session_callbacks_set_error_callback2, libnghttp2), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}), callbacks, cb)
    return nothing
end
