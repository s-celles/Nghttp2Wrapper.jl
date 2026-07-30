using Documenter
using Nghttp2Wrapper

makedocs(
    sitename = "Nghttp2Wrapper.jl",
    modules = [Nghttp2Wrapper],
    # api.md is a single @autodocs dump of the whole module, so it grows with
    # every docstring and crossed Documenter's default warn threshold. Raised
    # rather than silenced: the hard `size_threshold` still applies, so a page
    # that becomes genuinely unreasonable will still fail the build. Splitting
    # the reference by area would be the better long-term answer.
    format = Documenter.HTML(size_threshold = 400_000, size_threshold_warn = 350_000),
    pages = [
        "Home" => "index.md",
        "Client Guide" => "client.md",
        "Server Guide" => "server.md",
        "Low-Level API" => "lowlevel.md",
        "API Reference" => "api.md",
        "Advanced Features" => "advanced.md",
        "Benchmarks" => "benchmarks.md",
    ],
)

deploydocs(
    repo = "github.com/s-celles/Nghttp2Wrapper.jl.git",
    push_preview = true,
)
