# Contributing to Nghttp2Wrapper.jl

Thanks for your interest in contributing! This document covers the practical
workflow for working on this package.

By participating, you agree to uphold the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

- Julia **1.12** or newer (see `[compat]` in `Project.toml`)
- Git

### Local Setup

```sh
git clone https://github.com/s-celles/Nghttp2Wrapper.jl.git
cd Nghttp2Wrapper.jl
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Verify the baseline works before changing anything:

```sh
julia --project -e 'using Pkg; Pkg.test()'
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Both should complete with zero failures and zero documentation warnings.

## Development Workflow

This project follows **Test-Driven Development (TDD)**:

1. Write a failing test in `test/*_tests.jl` using a `@testitem` block.
2. Run the suite to confirm it is red.
3. Implement the minimum code to make it green.
4. Refactor, keeping the suite green.

Tests use [TestItemRunner.jl](https://github.com/julia-vscode/TestItemRunner.jl),
not the stdlib `Test.jl` runner. Each `@testitem` must be independently runnable
and must not leak state between items.

### Quality Gates

Before opening a pull request, confirm that locally:

- `julia --project -e 'using Pkg; Pkg.test()'` passes on all tests (including
  [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl) quality checks).
- `julia --project=docs docs/make.jl` builds the documentation with **zero
  warnings**.
- `CHANGELOG.md` has a new entry under `[Unreleased]` following the
  [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, describing
  user-visible changes (Added / Changed / Removed / Fixed / Security).
- New or changed public API is covered by docstrings and, where relevant,
  by a new or updated page under `docs/src/`.

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org):

- `feat:` — a new feature
- `fix:` — a bug fix
- `refactor:` — a code change that neither adds a feature nor fixes a bug
- `docs:` — documentation-only change
- `test:` — adding or updating tests
- `chore:` — build process, tooling, dependency bumps
- `ci:` — CI configuration changes

Scoped variants like `fix(server): …` or `refactor(tls): …` are welcome.

### Versioning

The project follows [Semantic Versioning](https://semver.org). Pre-1.0, minor
bumps may include breaking internal changes; the public API surface
(`HTTP2Client`, `HTTP2Server`, their constructors and exported names) is
preserved across minor bumps unless explicitly noted in `CHANGELOG.md`.

Only maintainers bump the version in `Project.toml`; contributors should leave
the version field unchanged in their PR.

## Pull Request Checklist

- [ ] Tests added or updated, and `Pkg.test()` passes locally on Julia 1.12+
- [ ] Documentation updated for any user-visible change, and `docs/make.jl`
      builds with zero warnings
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] Conventional commit message(s)
- [ ] Branch is up to date with `main`

CI runs the full test suite on Linux, macOS, and Windows. A PR is ready for
review once all three matrix jobs are green.

## Reporting Bugs

Open an issue on the [GitHub tracker](https://github.com/s-celles/Nghttp2Wrapper.jl/issues)
with:

- A minimal reproducer (prefer a small Julia snippet over a full application)
- Julia version, OS, and Nghttp2Wrapper.jl version
- Observed vs. expected behavior, with any stack traces

**Security issues** should be reported privately — see [SECURITY.md](SECURITY.md).

## Upstream Bugs

When you hit a defect that turns out to live in a dependency (`nghttp2_jll`,
`Reseau.jl`, etc.), please:

1. File the bug upstream.
2. Add a short entry to [`upstream-bugs.md`](upstream-bugs.md) in this repo so
   future contributors can find the context quickly.

## Questions

For general questions (not bug reports), open a GitHub Discussion or issue.
