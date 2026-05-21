# core — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `core/` grouping holds the
**wire-format specs** the rest of the toolchain is built around. They sit at the top of the
dependency chain: `core/` → `lang/` → `tooling/`.

## Routing a change

- `core/tii/` → [`tx3-lang/tii`](https://github.com/tx3-lang/tii) — TII (Transaction Invocation Interface) JSON Schema and example `.tii` artifacts. Spec-only, no source code.
- `core/tir/` → [`tx3-lang/tir`](https://github.com/tx3-lang/tir) — TIR (Transaction Intermediate Representation) wire-format specs (`specs/`) and the reference `tx3-tir` Rust crate. Consumed by `tx3` and `trix` from crates.io.
- `core/trp/` → [`tx3-lang/trp`](https://github.com/tx3-lang/trp) — TRP (Transaction Resolver Protocol) OpenRPC spec. Spec-only, no source code; protocol-type codegen will be handled at the toolchain level (planned, not yet built).

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.
