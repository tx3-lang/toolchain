---
name: release-core
description: Release the core/ grouping — publish the tx3-tir crate at a developer gate; tii/trp are spec-only (pointer-advance).
---

# release-core

Release the `core/` grouping: the root of the dependency graph. `core/tir` publishes the `tx3-tir`
crate (the breaking-schema crate every downstream pins); `core/tii` and `core/trp` are wire-format
specs with no release artifact today. Instantiates the umbrella
[`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md).

## When to use
- Invoked by the `release-toolchain` orchestrator as the first grouping in the wave.
- Standalone for a `core`-only release (a new `tx3-tir` schema is published before any consumer moves).

Do not use for downstream groupings — `core` has no upstream, so it never adopts a pin.

## Scope
- `core/tir` — `crate-publish`. Crate `tx3-tir` at `core/tir/crates/tx3-tir` (workspace version in
  `core/tir/Cargo.toml`).
- `core/tii`, `core/trp` — `pointer-only`. Spec repos (directory-versioned `v1beta0/`); no crate, no
  workflow, no tags. Toolchain-level protocol-type codegen from these specs is *planned, not built*, so
  there is no `codegen-v<TII>`-style tag to move yet.

## Inputs
- `target_channel`, `scope`, `bump_policy` per the contract.
- `upstream_versions` — empty; `core` is the graph root.

## Procedure
1. **Map scope.** `tir` = crate-publish; `tii`/`trp` = pointer-only.
2. **Confirm the version.** `core/tir/main` carries the merged schema change and the workspace
   `version` is the target. If a bump commit is still needed, that's `add-language-feature`'s small PR,
   not this skill. `tii`/`trp` need no edit — the spec is already merged.
3. **Build.** `cargo build --workspace` in `core/tir` (whole workspace; the schema add must compile
   reduce/model and the crate's own tests).
4. **Gate — manual crate publish.** `core/tir`'s `release.toml` sets `push = false, publish = false`,
   and the only workflow is `ci.yml`, so publishing is manual. State:
   > Publish `tx3-tir <version>` to crates.io (`cargo release <version> --execute` in `core/tir`, or
   > `cargo publish -p tx3-tir`), then confirm.

   **Stop and wait.** `tii`/`trp` have no gate — a spec change is just a merged file.
5. **Verify.** Confirm `tx3-tir <version>` resolves on the sparse index
   (`https://index.crates.io/tx/3-/tx3-tir`) before reporting.
6. **Report Outputs.**

## Outputs
- `crates: { "tx3-tir": "<version>" }`
- `pointers: [ "core/tir" ]` (+ `core/tii` / `core/trp` if their `main` advanced past the umbrella pin)

## Guardrails
- Never publish for the developer — state the crate + version and wait.
- `tii`/`trp` produce no release artifact; don't invent a gate or a tag for them.
- The build is the safety net for the schema add — build the **whole** `core/tir` workspace, not `-p`.

## Error handling
- **Workspace version still on the old number at the gate** — the bump commit hasn't merged; hold and
  land it (via `add-language-feature`), then publish.
- **`tx3-tir <version>` not on the sparse index after the gate** — the publish hasn't propagated or
  failed; re-check before declaring outputs. Downstream groupings must not start until it resolves.
