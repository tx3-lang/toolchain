---
name: release-tooling
description: Release the tooling/ grouping — adopt published upstreams, raise the trix compat floor, and gate each tool's crate publish / binary tag.
---

# release-tooling

Release the `tooling/` grouping. It is **heterogeneous** — each submodule releases differently — so the
skill branches by submodule type. Instantiates the umbrella
[`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md).

## When to use
- Invoked by the `release-toolchain` orchestrator after `core`, `lang`, and `sdks` have published.
- Standalone for a `tooling`-only release that adopts already-published upstreams.

Do not use to publish upstream crates (`tx3-tir`/`tx3-lang`/`tx3-sdk`) — those are `release-core` /
`release-lang` / the SDK fleet skills.

## Scope (classify each in-scope submodule)
| Submodule | Type | Pins / coupling | Release mechanism |
| --- | --- | --- | --- |
| `tx3-lsp` | `crate+binary` | `tx3-lang`, `tx3-tir` | tag → `release.yml` (cargo-dist binary) → chained `publish.yml` (`workflow_run`) `cargo release publish` → crate `tx3-lsp` |
| `tx3-mcp` | `binary-dist` | **exact `=` pins** `tx3-lang`,`tx3-cardano`,`tx3-tir`,`tx3-sdk` | tag → `release.yml` (cargo-dist binary). No crate. |
| `trix` | `floor-only` + `binary-dist` | **no `tx3-*` deps**; `COMPAT_MATRIX` floor + `dolos-core` git tag | tag → `release.yml` (cargo-dist binary) |
| `tx3up` | `binary-dist` | none (it's the installer) | tag → cargo-dist binary, `publish-jobs=["homebrew"]` |
| `tx3-lift` | `crate-publish` | `tx3-tir`, `tx3-sdk` | manual `cargo publish` (no CI workflow); crates `tx3-lift`, `tx3-lift-cardano` |
| `cshell` | `third-party-adopt` | — (`txpipe/cshell`) | not ours; adopt upstream release only |

## Inputs
- `upstream_versions` — published `tx3-tir`, `tx3-lang`, `tx3c`, `tx3-sdk` (whichever are in scope).
- `target_channel`, `scope`, `bump_policy` per the contract.

## Procedure
1. **Map + classify** each in-scope submodule (table above). Grep real pins:
   `grep -rn 'tx3-tir\s*=\|tx3-lang\s*=\|tx3-sdk\s*=' --include=Cargo.toml tooling`.
2. **Bump intra-grouping pins** to the adopted `upstream_versions`:
   - `tx3-lsp`: bump `tx3-lang` + `tx3-tir` **together**; bump its own version.
   - `tx3-mcp`: update the **exact `=` pins** to the adopted versions (`= ` means it cannot lag lang by
     even a patch — it moves in the same wave it adopts lang); bump its own version.
   - `tx3-lift`: bump `tx3-tir` + `tx3-sdk` in `[workspace.dependencies]`; bump the two crate versions.
   - `trix`: **no Cargo pin** — instead edit `src/spawn/compat.rs` `COMPAT_MATRIX` (`tx3c { min }`) to
     the producing `tx3c` release and update the rationale comment to name the new feature/variant; then
     `cargo test -p trix` (the `evaluate`/`collect_project_mins` tests gate this). Bump its own version.
   - `tx3up`: no upstream pin; bump only if it has its own pending changes.
   - `cshell`: no edit — adopt its upstream release version into `adopted`.
3. **Build** each in-scope workspace whole (`cargo build --workspace`), never `-p`. Distinguish compile
   breaks (block) from env failures (e.g. `DATABASE_URL`) and pre-existing drift (surface, don't block).
4. **Gate** — per submodule type:
   - tag-triggered (`tx3-lsp`, `tx3-mcp`, `trix`, `tx3up`): *"push tag `v<version>` in `tooling/<repo>`"*
     (cargo-dist builds the binary; for `tx3-lsp` the chained `publish.yml` also publishes the crate).
   - manual crate (`tx3-lift`): *"publish `tx3-lift` + `tx3-lift-cardano <version>` to crates.io"*.
   These are independent across submodules (no cross-pins among the tools) and can be cut together.
   **State exactly which, then stop and wait.**
5. **Verify** each: `gh release view --repo tx3-lang/<repo> v<version>` for binaries; sparse index for
   `tx3-lsp` / `tx3-lift` crates. `cshell` is adopt-only (skip).
6. **Report Outputs.**

## Outputs
- `crates: { "tx3-lsp": "<v>", "tx3-lift": "<v>", "tx3-lift-cardano": "<v>" }` (those in scope)
- `binaries: { "tx3-lsp": "v<v>", "tx3-mcp": "v<v>", "trix": "v<v>", "tx3up": "v<v>" }` (those in scope)
- `floors: { "tx3c": "<min>" }`  (the raised `trix` `COMPAT_MATRIX` minimum)
- `adopted: { "cshell": "<upstream version>" }`
- `pointers: [ "tooling/<each released submodule>" ]`

## Guardrails
- Adopt only verified-published upstreams; bump `tx3-lsp`'s `tx3-lang`+`tx3-tir` and `tx3-lift`'s
  `tx3-tir`+`tx3-sdk` in lockstep.
- `tx3-mcp`'s exact `=` pins must match the adopted versions exactly — a caret would resolve, but the
  repo's convention is exact, and a mismatch fails the build.
- `trix` links no `tx3-*` crate — its only coupling is the `COMPAT_MATRIX` floor; raise it only after
  `lang` actually published the producing `tx3c` (that's what makes the floor safe).
- Whole-workspace builds; revert any temporary patch + lockfile churn before committing.
- `cshell` is third-party — never tag or publish it; only adopt its upstream release.

## Error handling
- **`tx3-mcp` won't build: `links to two different versions`** — an exact `=` pin still points at the
  old version, or `tx3-sdk` wasn't published before tooling ran (sdks must precede tooling). Fix the
  pin / confirm the sdks gate closed.
- **`tx3-lsp` binary released but crate didn't publish** — `publish.yml` runs on `workflow_run` after
  Release; check it completed (`gh run list --repo tx3-lang/tx3-lsp`).
- **`cargo test -p trix` fails after the floor bump** — the `COMPAT_MATRIX` edit or rationale is
  inconsistent with the `collect_project_mins` expectations; reconcile before tagging `trix`.
- **`tx3-lift` consumed downstream by git-rev (registry)** — after `tx3-lift`'s bump commit merges,
  `release-registry` advances its git-rev to that commit. That's the downstream skill's job, not this one.
