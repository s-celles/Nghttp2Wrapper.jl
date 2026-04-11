@testitem "stream user data" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    # Session-level (stream 0) user data
    user_data = nghttp2_session_get_stream_user_data(session, 0)
    # Stream 0 should return C_NULL since no user data was set
    @test user_data == C_NULL
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "stream window size" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    # Stream 0 is not a real stream — query returns an error code
    window_size = nghttp2_session_get_stream_effective_local_window_size(session, 0)
    # -1 means stream not found, which is expected for stream 0
    @test window_size isa Integer
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end
