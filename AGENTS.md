# lang-factory — agent guide

A thin aggregator of the Tx3 toolkit. Real code lives in six submodules:

- `tx3/` → [`tx3-lang/tx3`](https://github.com/tx3-lang/tx3) — language: parser, analyzer, codegen.
- `trix/` → [`tx3-lang/trix`](https://github.com/tx3-lang/trix) — `trix` CLI / package manager.
- `tii/` → [`tx3-lang/tii`](https://github.com/tx3-lang/tii) — Transaction Invocation Interface spec (JSON Schema) + examples.
- `tir/` → [`tx3-lang/tir`](https://github.com/tx3-lang/tir) — Transaction Intermediate Representation: spec + reference Rust crate (`tx3-tir`).
- `trp/` → [`tx3-lang/trp`](https://github.com/tx3-lang/trp) — Transaction Resolver Protocol spec (OpenRPC).
- `docs/` → [`tx3-lang/docs`](https://github.com/tx3-lang/docs) — public docs.

## Routing a change

- `tx3/` — parser, type system, codegen, language semantics.
- `trix/` — `trix` CLI, `trix.toml`, scaffolding, devnet, codegen frontends, test runner.
- `tii/` — TII JSON Schema, example `.tii` artifacts. Spec-only, no source code.
- `tir/` — TIR wire-format specs (`specs/`) and the reference `tx3-tir` Rust crate. Consumed by `tx3` and `trix` from crates.io.
- `trp/` — TRP OpenRPC spec. Spec-only, no source code; protocol-type codegen will be handled at the factory level (planned, not yet built).
- `docs/` — user-facing docs, tutorials, reference, examples.

If a submodule has its own `AGENTS.md` / `CLAUDE.md` / `README.md`, it overrides this file for work inside that submodule.

Dependency direction for cross-cutting changes is typically `tii` / `trp` / `tir` → `tx3` → `trix` → `docs`.

## Scope of this repo

`lang-factory` is intentionally minimal. Do not add a top-level workspace, build script, or package manifest unless the user explicitly asks for one — the parent only holds submodule pointers and orchestration docs.
