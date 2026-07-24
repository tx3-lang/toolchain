# toolchain — agent guide

This repository is the source of truth for **Tx3 toolchain** release versions. It contains
only the release manifests and the GitHub workflow that cuts releases from them.

## Release manifests

`manifest-stable.json`, `manifest-beta.json`, and `manifest-nightly.json` pin the version of
each toolchain component (`tx3c`, `trix`, `tx3-lsp`, `tx3-mcp`, `dolos`, `cshell`, and `tx3up`)
shipped on each release channel. On every push to `main` that touches them,
`.github/workflows/release.yml` cuts a GitHub release with the manifests attached. Keep manifest
edits in their own commits.
