using Documenter
using Nghttp2Wrapper

makedocs(
    sitename = "Nghttp2Wrapper.jl",
    modules = [Nghttp2Wrapper],
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
