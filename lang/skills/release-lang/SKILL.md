---
name: release-lang
description: Release the lang/ grouping — one tag publishes tx3-lang/tx3-cardano/tx3-resolver and the tx3c binary, after adopting the published tx3-tir.
---

# release-lang

Release the `lang/` grouping: `lang/tx3` is a single workspace whose **one release tag** publishes three
crates (`tx3-lang`, `tx3-cardano`, `tx3-resolver`) *and* builds the `tx3c` binary atomically.
Instantiates the umbrella [`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md).

## When to use
- Invoked by the `release-toolchain` orchestrator after `core` published `tx3-tir`.
- Standalone for a `lang`-only release that adopts an already-published `tx3-tir`.

Do not use to publish `tx3-tir` (that's `release-core`) or downstream consumers (that's `release-tooling`).

## Scope
- `lang/tx3` — `crate+binary`. Workspace members: `crates/tx3-lang`, `crates/tx3-cardano`,
  `crates/tx3-resolver`, `bin/tx3c`. Workspace version + `tx3-tir` pin in `lang/tx3/Cargo.toml`.

## Inputs
- `upstream_versions` — must contain a published `tx3-tir` (e.g. `{ "tx3-tir": "0.18.0" }`).
- `target_channel`, `scope`, `bump_policy` per the contract.

## Procedure
1. **Map scope.** `tx3` = crate+binary.
2. **Bump pins.** Set the `tx3-tir` pin in the `lang/tx3` workspace to the adopted version; bump the
   workspace `version` (a breaking schema adoption is a 0.x minor). All three crates and `tx3c` share
   this version.
3. **Build.** `cargo build --workspace` in `lang/tx3` — must include `bin/tx3c` (the tuple rollout's
   broken match arm surfaced only on a whole-workspace build, not `-p tx3-lang`). `tx3-tir` is on
   crates.io now, so no patch is needed.
4. **Gate — push the release tag.** `release.toml` has `push = false, publish = false`; pushing the tag
   triggers `release.yml` (cargo-dist builds the `tx3c` binary release) which calls `publish-crates.yml`
   (`cargo publish --workspace --exclude tx3c --locked`). One tag does both. State:
   > In `lang/tx3`, run `cargo release <version> --execute` (stamps version + commit + tag `v<version>`)
   > and push the tag; this publishes `tx3-lang`/`tx3-cardano`/`tx3-resolver` to crates.io and cuts the
   > `tx3c` GitHub release. Confirm when both are done.

   **Stop and wait.**
5. **Verify.** `tx3-lang <version>` on the sparse index **and** `gh release view --repo tx3-lang/tx3
   v<version>` shows the `tx3c` assets.
6. **Report Outputs.**

## Outputs
- `crates: { "tx3-lang": "<version>", "tx3-cardano": "<version>", "tx3-resolver": "<version>" }`
- `binaries: { "tx3c": "v<version>" }`  (tx3c shares the workspace version)
- `pointers: [ "lang/tx3" ]`

## Guardrails
- Adopt only a verified-published `tx3-tir` — never bump the pin to an unpublished tir.
- The three crates + `tx3c` move on **one** version/tag; don't split them.
- Whole-workspace build, never `-p` — `bin/tx3c` must compile against the new TIR.

## Error handling
- **`links to two different versions of tx3-tir`** — the adopted `tx3-tir` isn't actually published, or
  an old pin lingers; re-confirm `core`'s gate closed and the pin points at the published version.
- **`release.yml` built the binary but crates didn't publish** — the `publish-crates.yml` step failed
  (e.g. a crate version already on crates.io); inspect the run, fix, and re-tag if needed before
  declaring `crates` outputs.
