module Nghttp2Wrapper

using nghttp2_jll
using Reseau: TLS
using URIs
using Sockets

include("constants.jl")
include("types.jl")
include("version.jl")
include("callbacks.jl")
include("session.jl")
include("frames.jl")
include("streams.jl")
include("hpack.jl")
include("validation.jl")
include("errors.jl")
include("nvpair.jl")
include("wrappers.jl")
include("request.jl")
include("response.jl")
include("client.jl")
include("client_methods.jl")
include("server_types.jl")
include("server.jl")
include("priority.jl")
include("pool.jl")
include("proxy.jl")
include("websocket.jl")

# Constants
export NGHTTP2_ERR_INVALID_ARGUMENT, NGHTTP2_ERR_BUFFER_ERROR,
       NGHTTP2_ERR_UNSUPPORTED_VERSION, NGHTTP2_ERR_WOULDBLOCK,
       NGHTTP2_ERR_PROTO, NGHTTP2_ERR_INVALID_FRAME, NGHTTP2_ERR_EOF,
       NGHTTP2_ERR_DEFERRED, NGHTTP2_ERR_STREAM_ID_NOT_AVAILABLE,
       NGHTTP2_ERR_STREAM_CLOSED, NGHTTP2_ERR_STREAM_CLOSING,
       NGHTTP2_ERR_STREAM_SHUT_WR, NGHTTP2_ERR_INVALID_STREAM_ID,
       NGHTTP2_ERR_INVALID_STREAM_STATE, NGHTTP2_ERR_DEFERRED_DATA_EXIST,
       NGHTTP2_ERR_START_STREAM_NOT_ALLOWED, NGHTTP2_ERR_GOAWAY_ALREADY_SENT,
       NGHTTP2_ERR_INVALID_HEADER_BLOCK, NGHTTP2_ERR_INVALID_STATE,
       NGHTTP2_ERR_TEMPORAL_CALLBACK_FAILURE, NGHTTP2_ERR_FRAME_SIZE_ERROR,
       NGHTTP2_ERR_HEADER_COMP, NGHTTP2_ERR_FLOW_CONTROL,
       NGHTTP2_ERR_INSUFF_BUFSIZE, NGHTTP2_ERR_PAUSE,
       NGHTTP2_ERR_TOO_MANY_INFLIGHT_SETTINGS, NGHTTP2_ERR_PUSH_DISABLED,
       NGHTTP2_ERR_DATA_EXIST, NGHTTP2_ERR_SESSION_CLOSING,
       NGHTTP2_ERR_HTTP_HEADER, NGHTTP2_ERR_HTTP_MESSAGING,
       NGHTTP2_ERR_REFUSED_STREAM, NGHTTP2_ERR_INTERNAL, NGHTTP2_ERR_CANCEL,
       NGHTTP2_ERR_SETTINGS_EXPECTED, NGHTTP2_ERR_TOO_MANY_SETTINGS,
       NGHTTP2_ERR_FATAL, NGHTTP2_ERR_NOMEM, NGHTTP2_ERR_CALLBACK_FAILURE,
       NGHTTP2_ERR_BAD_CLIENT_MAGIC, NGHTTP2_ERR_FLOODED,
       NGHTTP2_ERR_TOO_MANY_CONTINUATIONS

export NGHTTP2_NV_FLAG_NONE, NGHTTP2_NV_FLAG_NO_INDEX,
       NGHTTP2_NV_FLAG_NO_COPY_NAME, NGHTTP2_NV_FLAG_NO_COPY_VALUE

export NGHTTP2_DATA_FLAG_NONE, NGHTTP2_DATA_FLAG_EOF,
       NGHTTP2_DATA_FLAG_NO_END_STREAM, NGHTTP2_DATA_FLAG_NO_COPY

export NGHTTP2_SETTINGS_HEADER_TABLE_SIZE, NGHTTP2_SETTINGS_ENABLE_PUSH,
       NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS,
       NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE, NGHTTP2_SETTINGS_MAX_FRAME_SIZE,
       NGHTTP2_SETTINGS_MAX_HEADER_LIST_SIZE

export NGHTTP2_FLAG_NONE, NGHTTP2_FLAG_END_STREAM,
       NGHTTP2_FLAG_END_HEADERS, NGHTTP2_FLAG_ACK

export NGHTTP2_HD_INFLATE_FINAL, NGHTTP2_HD_INFLATE_EMIT

# Types
export Nghttp2Info, Nghttp2Nv, Nghttp2SettingsEntry

# Version & error handling
export nghttp2_version, nghttp2_strerror, nghttp2_is_fatal

# Callbacks
export nghttp2_session_callbacks_new, nghttp2_session_callbacks_del,
       nghttp2_session_callbacks_set_on_frame_recv_callback,
       nghttp2_session_callbacks_set_on_data_chunk_recv_callback,
       nghttp2_session_callbacks_set_on_stream_close_callback,
       nghttp2_session_callbacks_set_on_header_callback,
       nghttp2_session_callbacks_set_on_begin_headers_callback,
       nghttp2_session_callbacks_set_before_frame_send_callback,
       nghttp2_session_callbacks_set_on_frame_send_callback,
       nghttp2_session_callbacks_set_on_frame_not_send_callback,
       nghttp2_session_callbacks_set_send_callback2,
       nghttp2_session_callbacks_set_recv_callback2,
       nghttp2_session_callbacks_set_error_callback2

# Session lifecycle & I/O
export nghttp2_session_client_new, nghttp2_session_server_new,
       nghttp2_session_del,
       nghttp2_option_new, nghttp2_option_del,
       nghttp2_option_set_no_auto_window_update,
       nghttp2_option_set_peer_max_concurrent_streams,
       nghttp2_session_mem_send2, nghttp2_session_mem_recv2,
       nghttp2_session_want_read, nghttp2_session_want_write

# Frame submission
export nghttp2_submit_request2, nghttp2_submit_response2,
       nghttp2_submit_headers, nghttp2_submit_settings,
       nghttp2_submit_ping, nghttp2_submit_goaway,
       nghttp2_submit_rst_stream, nghttp2_submit_window_update,
       nghttp2_submit_push_promise

# Stream management
export nghttp2_session_find_stream,
       nghttp2_session_get_stream_user_data,
       nghttp2_session_set_stream_user_data,
       nghttp2_session_get_stream_effective_local_window_size,
       nghttp2_session_get_stream_effective_recv_data_length

# HPACK
export nghttp2_hd_deflate_new, nghttp2_hd_deflate_del,
       nghttp2_hd_deflate_hd2,
       nghttp2_hd_inflate_new, nghttp2_hd_inflate_del,
       nghttp2_hd_inflate_hd2

# Validation
export nghttp2_check_header_name, nghttp2_check_header_value,
       nghttp2_check_authority, nghttp2_check_path, nghttp2_check_method

# Milestone 2: Error handling
export Nghttp2Error, check_error

# Milestone 2: NVPair
export NVPair, to_nghttp2_nv, with_nva

# Milestone 2: Wrapper types
export Callbacks, Option, Session, HpackDeflater, HpackInflater
export set_peer_max_concurrent_streams!, set_no_auto_window_update!
export submit_settings!, send!, recv!, want_read, want_write
export submit_ping!, submit_goaway!
export deflate, inflate

# Milestone 3: HTTP/2 Client
export HTTP2Client, Request, Response
export request, request_stream, shutdown!
export post, put, patch, head, options

# Milestone 4: HTTP/2 Server
export HTTP2Server, ServerRequest, ServerResponse

# Milestone 6: Advanced Features
export PrioritySpec
export ConnectionPool, acquire, release, pool_request, pool_get, pool_post
export forward_request
export websocket_connect
export inspect_dynamic_table, dynamic_table_size

end
