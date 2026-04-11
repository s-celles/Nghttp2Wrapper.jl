@testitem "session mem_send2" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    # Submit empty settings to trigger connection preface + SETTINGS
    nghttp2_submit_settings(session)
    nbytes, data_ptr = nghttp2_session_mem_send2(session)
    @test nbytes > 0
    # Client connection preface is 24 bytes "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
    # plus a SETTINGS frame (9 bytes header + payload)
    @test nbytes >= 24
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "session want_read want_write" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    rv_sess, session = nghttp2_session_client_new(callbacks)
    nghttp2_submit_settings(session)
    @test nghttp2_session_want_write(session) == true
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end
