"""
    nghttp2_session_find_stream(session, stream_id) → Ptr{Cvoid}

Find a stream by its ID. Returns a stream pointer or `C_NULL`.
"""
function nghttp2_session_find_stream(session::Ptr{Cvoid}, stream_id::Integer)
    ccall((:nghttp2_session_find_stream, libnghttp2), Ptr{Cvoid},
          (Ptr{Cvoid}, Int32), session, stream_id)
end

"""
    nghttp2_session_resume_data(session, stream_id) → Cint

Un-defer a stream's data provider.

A data provider that has nothing to send returns `NGHTTP2_ERR_DEFERRED` rather
than end-of-data, and nghttp2 then stops asking. This is what tells it to ask
again — without it an incremental handler's later writes are never collected.

Returns 0, or `NGHTTP2_ERR_INVALID_ARGUMENT` if the stream does not exist or was
not deferred.
"""
function nghttp2_session_resume_data(session::Ptr{Cvoid}, stream_id::Integer)
    ccall((:nghttp2_session_resume_data, libnghttp2), Cint,
          (Ptr{Cvoid}, Int32), session, stream_id)
end

"""
    nghttp2_session_get_stream_user_data(session, stream_id) → Ptr{Cvoid}

Get the user data associated with a stream.
"""
function nghttp2_session_get_stream_user_data(session::Ptr{Cvoid}, stream_id::Integer)
    ccall((:nghttp2_session_get_stream_user_data, libnghttp2), Ptr{Cvoid},
          (Ptr{Cvoid}, Int32), session, stream_id)
end

"""
    nghttp2_session_get_last_proc_stream_id(session) → Int32

Return the ID of the last stream the session finished processing.

This is the value a GOAWAY frame should carry: it tells the peer exactly how far
its requests were honoured, so anything above it can safely be retried on a new
connection (RFC 7540 §6.8).
"""
function nghttp2_session_get_last_proc_stream_id(session::Ptr{Cvoid})
    ccall((:nghttp2_session_get_last_proc_stream_id, libnghttp2), Int32,
          (Ptr{Cvoid},), session)
end

"""
    nghttp2_session_set_stream_user_data(session, stream_id, user_data) → Cint

Set the user data associated with a stream.
"""
function nghttp2_session_set_stream_user_data(session::Ptr{Cvoid}, stream_id::Integer,
                                               user_data::Ptr{Cvoid})
    ccall((:nghttp2_session_set_stream_user_data, libnghttp2), Cint,
          (Ptr{Cvoid}, Int32, Ptr{Cvoid}), session, stream_id, user_data)
end

"""
    nghttp2_session_get_stream_effective_local_window_size(session, stream_id) → Int32

Get the effective local window size for a stream.
"""
function nghttp2_session_get_stream_effective_local_window_size(session::Ptr{Cvoid}, stream_id::Integer)
    ccall((:nghttp2_session_get_stream_effective_local_window_size, libnghttp2), Int32,
          (Ptr{Cvoid}, Int32), session, stream_id)
end

"""
    nghttp2_session_get_stream_effective_recv_data_length(session, stream_id) → Int32

Get the effective recv data length for a stream.
"""
function nghttp2_session_get_stream_effective_recv_data_length(session::Ptr{Cvoid}, stream_id::Integer)
    ccall((:nghttp2_session_get_stream_effective_recv_data_length, libnghttp2), Int32,
          (Ptr{Cvoid}, Int32), session, stream_id)
end
