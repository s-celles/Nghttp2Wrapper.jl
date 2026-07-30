"""
    nghttp2_submit_settings(session, flags, iv, niv) → Cint

Submit a SETTINGS frame. `iv` is a pointer to an array of
`Nghttp2SettingsEntry` and `niv` is the number of entries.
"""
function nghttp2_submit_settings(session::Ptr{Cvoid}, flags::Integer,
                                  iv::Ptr{Nghttp2SettingsEntry}, niv::Integer)
    ccall((:nghttp2_submit_settings, libnghttp2), Cint,
          (Ptr{Cvoid}, UInt8, Ptr{Nghttp2SettingsEntry}, Csize_t),
          session, flags, iv, niv)
end

function nghttp2_submit_settings(session::Ptr{Cvoid}, flags::Integer,
                                  iv::Vector{Nghttp2SettingsEntry})
    nghttp2_submit_settings(session, flags, pointer(iv), length(iv))
end

function nghttp2_submit_settings(session::Ptr{Cvoid})
    nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE,
                            Ptr{Nghttp2SettingsEntry}(C_NULL), 0)
end

"""
    nghttp2_submit_request2(session, pri_spec, nva, nvlen, data_prd, stream_user_data) → Int32

Submit a request. Returns the stream ID on success, or a negative error code.
"""
function nghttp2_submit_request2(session::Ptr{Cvoid}, pri_spec::Ptr{Cvoid},
                                  nva::Ptr{Nghttp2Nv}, nvlen::Integer,
                                  data_prd::Ptr{Cvoid}, stream_user_data::Ptr{Cvoid})
    ccall((:nghttp2_submit_request2, libnghttp2), Int32,
          (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Nghttp2Nv}, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}),
          session, pri_spec, nva, nvlen, data_prd, stream_user_data)
end

"""
    nghttp2_submit_response2(session, stream_id, nva, nvlen, data_prd) → Cint

Submit a response on the given stream.
"""
function nghttp2_submit_response2(session::Ptr{Cvoid}, stream_id::Integer,
                                   nva::Ptr{Nghttp2Nv}, nvlen::Integer,
                                   data_prd::Ptr{Cvoid})
    ccall((:nghttp2_submit_response2, libnghttp2), Cint,
          (Ptr{Cvoid}, Int32, Ptr{Nghttp2Nv}, Csize_t, Ptr{Cvoid}),
          session, stream_id, nva, nvlen, data_prd)
end

"""
    nghttp2_submit_trailer(session, stream_id, nva, nvlen) → Cint

Submit a trailing HEADERS block on `stream_id`, closing the stream.

Trailers are how a gRPC response terminates: the status travels in a HEADERS
frame sent *after* the body, not in the response headers (RFC 7540 §8.1, and
the gRPC HTTP/2 protocol binding). A server that cannot emit them cannot
complete a gRPC call.

Call this after the response body has been submitted. nghttp2 sets END_STREAM
on the frame itself, so no flag argument is taken.

Returns 0 on success, or a negative nghttp2 error code — notably
`NGHTTP2_ERR_INVALID_ARGUMENT` for an unknown or already-closed stream.
"""
function nghttp2_submit_trailer(session::Ptr{Cvoid}, stream_id::Integer,
                                 nva::Ptr{Nghttp2Nv}, nvlen::Integer)
    ccall((:nghttp2_submit_trailer, libnghttp2), Cint,
          (Ptr{Cvoid}, Int32, Ptr{Nghttp2Nv}, Csize_t),
          session, stream_id, nva, nvlen)
end

"""
    nghttp2_submit_headers(session, flags, stream_id, pri_spec, nva, nvlen, stream_user_data) → Int32

Submit a HEADERS frame.
"""
function nghttp2_submit_headers(session::Ptr{Cvoid}, flags::Integer,
                                 stream_id::Integer, pri_spec::Ptr{Cvoid},
                                 nva::Ptr{Nghttp2Nv}, nvlen::Integer,
                                 stream_user_data::Ptr{Cvoid})
    ccall((:nghttp2_submit_headers, libnghttp2), Int32,
          (Ptr{Cvoid}, UInt8, Int32, Ptr{Cvoid}, Ptr{Nghttp2Nv}, Csize_t, Ptr{Cvoid}),
          session, flags, stream_id, pri_spec, nva, nvlen, stream_user_data)
end

"""
    nghttp2_submit_ping(session, flags, opaque_data) → Cint

Submit a PING frame. `opaque_data` must be a pointer to 8 bytes or `C_NULL`.
"""
function nghttp2_submit_ping(session::Ptr{Cvoid}, flags::Integer, opaque_data::Ptr{UInt8})
    ccall((:nghttp2_submit_ping, libnghttp2), Cint,
          (Ptr{Cvoid}, UInt8, Ptr{UInt8}), session, flags, opaque_data)
end

function nghttp2_submit_ping(session::Ptr{Cvoid})
    nghttp2_submit_ping(session, NGHTTP2_FLAG_NONE, Ptr{UInt8}(C_NULL))
end

"""
    nghttp2_submit_goaway(session, flags, last_stream_id, error_code, opaque_data, opaque_data_len) → Cint

Submit a GOAWAY frame.
"""
function nghttp2_submit_goaway(session::Ptr{Cvoid}, flags::Integer,
                                last_stream_id::Integer, error_code::Integer,
                                opaque_data::Ptr{UInt8}, opaque_data_len::Integer)
    ccall((:nghttp2_submit_goaway, libnghttp2), Cint,
          (Ptr{Cvoid}, UInt8, Int32, UInt32, Ptr{UInt8}, Csize_t),
          session, flags, last_stream_id, error_code, opaque_data, opaque_data_len)
end

function nghttp2_submit_goaway(session::Ptr{Cvoid}, last_stream_id::Integer, error_code::Integer)
    nghttp2_submit_goaway(session, NGHTTP2_FLAG_NONE, last_stream_id, error_code,
                          Ptr{UInt8}(C_NULL), 0)
end

"""
    nghttp2_submit_rst_stream(session, flags, stream_id, error_code) → Cint

Submit a RST_STREAM frame.
"""
function nghttp2_submit_rst_stream(session::Ptr{Cvoid}, flags::Integer,
                                    stream_id::Integer, error_code::Integer)
    ccall((:nghttp2_submit_rst_stream, libnghttp2), Cint,
          (Ptr{Cvoid}, UInt8, Int32, UInt32),
          session, flags, stream_id, error_code)
end

"""
    nghttp2_submit_window_update(session, flags, stream_id, window_size_increment) → Cint

Submit a WINDOW_UPDATE frame.
"""
function nghttp2_submit_window_update(session::Ptr{Cvoid}, flags::Integer,
                                       stream_id::Integer, window_size_increment::Integer)
    ccall((:nghttp2_submit_window_update, libnghttp2), Cint,
          (Ptr{Cvoid}, UInt8, Int32, Int32),
          session, flags, stream_id, window_size_increment)
end

"""
    nghttp2_submit_push_promise(session, flags, stream_id, nva, nvlen, stream_user_data) → Int32

Submit a PUSH_PROMISE frame. Returns the promised stream ID.
"""
function nghttp2_submit_push_promise(session::Ptr{Cvoid}, flags::Integer,
                                      stream_id::Integer,
                                      nva::Ptr{Nghttp2Nv}, nvlen::Integer,
                                      stream_user_data::Ptr{Cvoid})
    ccall((:nghttp2_submit_push_promise, libnghttp2), Int32,
          (Ptr{Cvoid}, UInt8, Int32, Ptr{Nghttp2Nv}, Csize_t, Ptr{Cvoid}),
          session, flags, stream_id, nva, nvlen, stream_user_data)
end
