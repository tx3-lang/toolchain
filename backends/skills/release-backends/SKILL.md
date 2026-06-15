---
name: release-backends
description: Flag-and-defer check for the backends/ grouping — report how far tx3-hydra / protocol-gateway lag the released toolchain; never auto-bump them.
---

# release-backends

The `backends/` grouping holds deploy-on-branch execution services, not published artifacts. This skill
**flags and defers**: it reports how far each backend's toolchain pins lag the just-released upstreams
and lets the developer decide — it never auto-bumps. Instantiates the umbrella
[`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md), specializing it to a
*report*, not a publish.

## When to use
- Invoked by the `release-toolchain` orchestrator after `tooling` released, to surface backend lag.
- Standalone to audit how stale the backends are vs the current toolchain.

Do not use this skill to drag a backend onto a new toolchain version automatically — backends may be
pinned to an older toolchain *intentionally* (deploy stability). Bumping one is a separate, explicit
decision the developer opts into.

## Scope
| Submodule | Type | Pins | Release mechanism |
| --- | --- | --- | --- |
| `tx3-hydra` | deploy-only | `tx3-resolver`, `tx3-cardano` (often stale, e.g. `0.16.2`) | Docker image on `main` push (`build.yml`); **no semver tags** |
| `protocol-gateway` | deploy-only | `tx3-sdk` (often stale, e.g. `0.9.2`) | Docker image on `main` push (`docker.yml`); **no semver tags** |
| `dolos` | `third-party-adopt` | — (`txpipe/dolos`) | upstream cargo-dist release; we only adopt |

## Inputs
- `upstream_versions` — the just-released `tx3-lang`/`tx3-cardano`/`tx3-resolver`/`tx3-sdk`, used to
  compute lag.
- `target_channel`, `scope`, `bump_policy` per the contract.

## Procedure
1. **Map scope.** `tx3-hydra` / `protocol-gateway` = deploy-only; `dolos` = third-party-adopt.
2. **Compute lag — do not edit.** Grep each backend's current `tx3-*` / `tx3-sdk` pins
   (`grep -rn 'tx3-\|tx3-sdk' --include=Cargo.toml backends`) and compare to `upstream_versions`. Record
   the delta per backend (e.g. `tx3-hydra: tx3-resolver 0.16.2 → 0.22.0 (behind)`).
3. **Adopt `dolos`.** Record its current upstream release version into `adopted` (it feeds the manifest).
4. **No gate.** There is nothing to publish. (If — and only if — the developer explicitly opts to bump a
   backend onto the new toolchain, that becomes a normal dep-bump + whole-workspace build + PR landing,
   done as a separate task, not part of the default release.)
5. **Verify.** Nothing to verify for the deploy-only backends; for `dolos`, confirm the adopted version
   is a real upstream release.
6. **Report Outputs** — primarily the lag report.

## Outputs
- `adopted: { "dolos": "<upstream version>" }`
- `skipped: [ { "submodule": "tx3-hydra", "reason": "behind: tx3-resolver 0.16.2 vs 0.22.0 — deferred" },
             { "submodule": "protocol-gateway", "reason": "behind: tx3-sdk 0.9.2 vs 0.11.0 — deferred" } ]`
- `pointers: []` (no pointer moves unless the developer opted into a bump)

## Guardrails
- **Never auto-bump a backend.** Report the lag; the developer decides.
- Backends have no semver releases — don't expect or invent a publish gate.
- `dolos` is third-party — adopt only; never tag or publish it.

## Error handling
- **A backend's pin is *ahead* of `upstream_versions`** — unusual; surface it (the backend may track a
  pre-release). Don't "fix" it.
- **Developer asks to bump a backend now** — treat as a separate dep-bump task: bump pins, build the
  whole workspace, land the PR, and add the pointer to `pointers` — but only on explicit request.
