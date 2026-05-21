# lang — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `lang/` grouping holds the **Tx3
language** itself. It depends on the `core/` specs and is consumed by everything in
`tooling/`.

## Routing a change

- `lang/tx3/` → [`tx3-lang/tx3`](https://github.com/tx3-lang/tx3) — the language: parser, analyzer, type system, codegen, and language semantics.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.
