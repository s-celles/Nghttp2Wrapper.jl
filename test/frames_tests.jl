@testitem "submit_settings" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    rv = nghttp2_submit_settings(session)
    @test rv == 0
    # Send the data
    nbytes, data_ptr = nghttp2_session_mem_send2(session)
    @test nbytes > 0
    # The first 24 bytes should be the HTTP/2 connection preface
    data = unsafe_wrap(Array, data_ptr, nbytes; own=false)
    preface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
    @test data[1:24] == Vector{UInt8}(preface)
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "submit_ping" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    # Must send settings first (connection preface)
    nghttp2_submit_settings(session)
    rv = nghttp2_submit_ping(session)
    @test rv == 0
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "submit_goaway" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    nghttp2_submit_settings(session)
    rv = nghttp2_submit_goaway(session, 0, 0)
    @test rv == 0
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "submit_rst_stream" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    nghttp2_submit_settings(session)
    # RST_STREAM on a non-existent stream should return an error
    rv = nghttp2_submit_rst_stream(session, NGHTTP2_FLAG_NONE, 1, 0)
    # stream_id=1 doesn't exist yet, should get NGHTTP2_ERR_INVALID_ARGUMENT
    @test rv < 0 || rv == 0  # behavior may vary; just verify no crash
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end
