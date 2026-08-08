# Mutual TLS on the server (ROADMAP Milestone 8.3).
#
# `HTTP2Server` accepted a certificate and a key and nothing else, so a caller
# asking for a client CA or a minimum protocol version had nowhere to say so —
# and in gRPCServer.jl those were silently discarded, which meant one could
# configure mTLS and get a server that never verified a client certificate.
#
# These tests assert on the *handshake outcome*, which is what certificate
# verification decides. The HTTP/2 layer above it is covered elsewhere, and
# proving mTLS does not require driving a request through it.

@testitem "TLS-only options are refused on a plaintext listener" begin
    using Nghttp2Wrapper

    # Refusing beats ignoring. A server that takes a client CA and then never
    # verifies anything is the exact failure this milestone exists to remove,
    # and it is invisible until someone tests it — which is to say, never.
    handler = req -> ServerResponse(200, "OK")

    err = try
        HTTP2Server(handler, 0; client_ca = "/nonexistent/ca.crt")
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("certfile", sprint(showerror, err))

    err2 = try
        HTTP2Server(handler, 0; require_client_cert = true)
        nothing
    catch e
        e
    end
    @test err2 isa ArgumentError

    err3 = try
        HTTP2Server(handler, 0; min_tls_version = :TLSv1_3)
        nothing
    catch e
        e
    end
    @test err3 isa ArgumentError
end

@testitem "a client certificate signed by the configured CA is accepted" begin
    using Nghttp2Wrapper
    # Reached through the package rather than declared as a test dependency:
    # this guarantees the client speaks the very TLS the server was built
    # against, which is the whole point of an mTLS test.
    const TLS = Nghttp2Wrapper.TLS

    fixtures = joinpath(@__DIR__, "fixtures")
    for f in ("server.crt", "server.key", "ca.crt", "client.crt", "client.key")
        # Loud, not silent: a missing fixture must fail the test rather than
        # quietly turn it into a no-op.
        @test isfile(joinpath(fixtures, f))
    end

    server = HTTP2Server(0;
                         certfile = joinpath(fixtures, "server.crt"),
                         keyfile = joinpath(fixtures, "server.key"),
                         client_ca = joinpath(fixtures, "ca.crt"),
                         require_client_cert = true) do req
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    # Keyword form rather than a prebuilt `TLS.Config`: `connect(network,
    # address, config)` only exists in later Reseau 1.x, and this package
    # declares `Reseau = "1"`. A test that needs a newer API than the package
    # does turns a truthful bound into a lie nobody checks.
    connect_kwargs = (; cert_file = joinpath(fixtures, "client.crt"),
                        key_file = joinpath(fixtures, "client.key"),
                        alpn_protocols = ["h2"],
                        verify_peer = false)
    # A function, not a bare `try`: a try block at module top level is its own
    # scope, so assigning to an outer binding inside one silently creates a
    # local and leaves the outer value untouched.
    function try_connect(port, kwargs)
        try
            return (TLS.connect("tcp", "127.0.0.1:$(port)"; kwargs...), nothing)
        catch e
            return (nothing, e)
        end
    end

    conn, err = try_connect(port, connect_kwargs)
    @test err === nothing
    @test conn !== nothing
    if conn !== nothing
        @test TLS.connection_state(conn).handshake_complete
        try; close(conn); catch; end
    end

    close(server)
end

@testitem "a client with no certificate is rejected" begin
    using Nghttp2Wrapper
    # Reached through the package rather than declared as a test dependency:
    # this guarantees the client speaks the very TLS the server was built
    # against, which is the whole point of an mTLS test.
    const TLS = Nghttp2Wrapper.TLS

    fixtures = joinpath(@__DIR__, "fixtures")
    server = HTTP2Server(0;
                         certfile = joinpath(fixtures, "server.crt"),
                         keyfile = joinpath(fixtures, "server.key"),
                         client_ca = joinpath(fixtures, "ca.crt"),
                         require_client_cert = true) do req
        ServerResponse(200, "OK")
    end
    port = Nghttp2Wrapper.listener_port(server)

    # Same connection, no client certificate offered.
    rejected = try
        conn = TLS.connect("tcp", "127.0.0.1:$(port)";
                           alpn_protocols = ["h2"], verify_peer = false)
        # Some stacks complete the client's side and only fail on first use, so
        # a completed handshake alone does not prove acceptance.
        state = TLS.connection_state(conn)
        ok = state.handshake_complete
        if ok
            try
                write(conn, UInt8[0x00])
                read(conn, 1)
                ok = false      # the peer talked to us: not rejected
            catch
                ok = true
            end
        end
        try; close(conn); catch; end
        ok
    catch
        true                    # refused outright
    end
    @test rejected

    close(server)
end
