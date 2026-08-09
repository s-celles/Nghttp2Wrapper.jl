# Generates the mutual-TLS test fixtures, on demand, into this directory.
#
# Nothing here is committed. Private keys do not belong in a repository, and
# committed certificates are a time bomb that expires long after anyone
# remembers they exist.
#
# The failure this guards against is the *other* one: gRPCServer.jl gitignored
# its certificates and generated them from a script nobody called, so every TLS
# test skipped itself in CI while the jobs stayed green — the whole TLS surface
# was untested and reported as passing. So generation is not left to the reader:
# `runtests.jl` calls this before running anything, and the tests assert the
# files exist rather than skipping when they do not.
#
# Produces the server's own self-signed certificate, a throwaway CA, and a
# client certificate signed by that CA. For mutual TLS the server verifies the
# *client* against `ca.crt`, while its own certificate is the self-signed one
# the test client accepts by not verifying it.

const FIXTURES = @__DIR__
const MTLS_FILES = ("server.crt", "server.key",
                    "ca.crt", "ca.key", "client.crt", "client.key")

"""
    mtls_fixtures_present() -> Bool

Whether every mutual-TLS fixture is already on disk.
"""
mtls_fixtures_present() = all(isfile(joinpath(FIXTURES, f)) for f in MTLS_FILES)

"""
    generate_mtls_certificates(; force = false)

Create the TLS fixtures if they are missing. Raises if `openssl` is not
available, rather than returning quietly — a silent return here is how a whole
test surface disappears without anyone noticing.
"""
function generate_mtls_certificates(; force::Bool = false)
    !force && mtls_fixtures_present() && return nothing

    openssl = Sys.which("openssl")
    openssl === nothing && error(
        "openssl is required to generate the mutual TLS test fixtures " *
        "(expected in $(FIXTURES)). Install it, or run the TLS tests on a " *
        "machine that has it — do not skip them silently.")

    days = "3650"
    sv_crt = joinpath(FIXTURES, "server.crt")
    sv_key = joinpath(FIXTURES, "server.key")
    ca_crt = joinpath(FIXTURES, "ca.crt")
    ca_key = joinpath(FIXTURES, "ca.key")
    cl_crt = joinpath(FIXTURES, "client.crt")
    cl_key = joinpath(FIXTURES, "client.key")
    cl_csr = joinpath(FIXTURES, "client.csr")
    ca_srl = joinpath(FIXTURES, "ca.srl")

    # The server certificate. A subjectAltName is set because the committed
    # fixture it replaces had none, and a certificate identified only by CN is
    # rejected outright by anything modern.
    run(pipeline(`$openssl req -x509 -newkey rsa:2048 -nodes -days $days
                  -keyout $sv_key -out $sv_crt
                  -subj "/CN=localhost"
                  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"`,
                 stdout = devnull, stderr = devnull))

    run(pipeline(`$openssl req -x509 -newkey rsa:2048 -nodes -days $days
                  -keyout $ca_key -out $ca_crt
                  -subj "/CN=Nghttp2Wrapper test CA"
                  -addext "basicConstraints=critical,CA:TRUE"
                  -addext "keyUsage=critical,keyCertSign,cRLSign"`,
                 stdout = devnull, stderr = devnull))

    run(pipeline(`$openssl req -newkey rsa:2048 -nodes
                  -keyout $cl_key -out $cl_csr
                  -subj "/CN=nghttp2wrapper-test-client"`,
                 stdout = devnull, stderr = devnull))

    ext = tempname()
    write(ext, """
    basicConstraints=critical,CA:FALSE
    keyUsage=critical,digitalSignature,keyEncipherment
    extendedKeyUsage=clientAuth
    subjectAltName=DNS:nghttp2wrapper-test-client
    """)
    run(pipeline(`$openssl x509 -req -in $cl_csr -days $days
                  -CA $ca_crt -CAkey $ca_key -CAcreateserial
                  -extfile $ext -out $cl_crt`,
                 stdout = devnull, stderr = devnull))

    rm(ext; force = true)
    rm(cl_csr; force = true)
    rm(ca_srl; force = true)
    return nothing
end
