# tooling — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `tooling/` grouping holds the
**toolchain binaries and developer tools** built on top of `lang/` and `core/`.

## Routing a change

- `tooling/trix/` → [`tx3-lang/trix`](https://github.com/tx3-lang/trix) — `trix` CLI / package manager: `trix.toml`, scaffolding, devnet, codegen frontends, test runner.
- `tooling/tx3up/` → [`tx3-lang/tx3up`](https://github.com/tx3-lang/tx3up) — the `tx3up` toolchain installer / version manager.
- `tooling/tx3-lsp/` → [`tx3-lang/tx3-lsp`](https://github.com/tx3-lang/tx3-lsp) — `tx3-lsp` language server.
- `tooling/tx3-mcp/` → [`tx3-lang/tx3-mcp`](https://github.com/tx3-lang/tx3-mcp) — MCP server exposing the toolchain to AI agents / editors.
- `tooling/tx3-lift/` → [`tx3-lang/tx3-lift`](https://github.com/tx3-lang/tx3-lift) — semantic-enrichment framework: annotates on-chain txs with Tx3 protocol context.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.
