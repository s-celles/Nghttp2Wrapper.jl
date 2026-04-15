#
# Minimal HTTP/2 "hello world" server reachable from a browser.
#
# Browsers (Chrome, Firefox, Safari, Edge) only speak HTTP/2 over TLS with
# ALPN — they do NOT support h2c (plaintext HTTP/2). This example therefore
# starts a TLS server using the self-signed certificate shipped under
# `test/fixtures/`, which is suitable for local experimentation only.
#
# Run from the repository root:
#
#     julia --project=. examples/browser_hello.jl
#
# Then open https://localhost:8443 in your browser and accept the self-signed
# certificate warning. To confirm HTTP/2 is actually being used, open the
# browser DevTools Network tab and enable the "Protocol" column — you should
# see `h2`.
#

using Nghttp2Wrapper

const FIXTURES = joinpath(@__DIR__, "..", "test", "fixtures")
const CERT = joinpath(FIXTURES, "server.crt")
const KEY  = joinpath(FIXTURES, "server.key")

server = HTTP2Server(8443; certfile=CERT, keyfile=KEY) do req
    ServerResponse(200, "Hello HTTP/2!")
end

println("HTTP/2 server listening on https://localhost:8443  (Ctrl-C to stop)")
flush(stdout)

try
    while isopen(server)
        sleep(1)
    end
catch e
    e isa InterruptException || rethrow()
finally
    close(server)
    println("Server stopped.")
end
