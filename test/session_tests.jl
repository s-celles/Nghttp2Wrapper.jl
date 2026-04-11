@testitem "callbacks lifecycle" begin
    using Nghttp2Wrapper
    rv, callbacks = nghttp2_session_callbacks_new()
    @test rv == 0
    @test callbacks != C_NULL
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "client session lifecycle" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    @test rv_cb == 0
    rv_sess, session = nghttp2_session_client_new(callbacks)
    @test rv_sess == 0
    @test session != C_NULL
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "server session lifecycle" begin
    using Nghttp2Wrapper
    rv_cb, callbacks = nghttp2_session_callbacks_new()
    @test rv_cb == 0
    rv_sess, session = nghttp2_session_server_new(callbacks)
    @test rv_sess == 0
    @test session != C_NULL
    nghttp2_session_del(session)
    nghttp2_session_callbacks_del(callbacks)
end

@testitem "session options" begin
    using Nghttp2Wrapper
    rv, option = nghttp2_option_new()
    @test rv == 0
    @test option != C_NULL
    nghttp2_option_set_peer_max_concurrent_streams(option, 100)
    nghttp2_option_set_no_auto_window_update(option, 1)
    nghttp2_option_del(option)
end
