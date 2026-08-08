using TestItemRunner

# Generate the mutual-TLS fixtures before anything runs. Deliberately not left
# to the reader or to a `@testitem`: certificates and keys are not committed,
# and a test that skips because a fixture is missing is how an entire TLS
# surface goes untested while CI stays green.
include(joinpath(@__DIR__, "fixtures", "generate_mtls_certs.jl"))
generate_mtls_certificates()

@run_package_tests
