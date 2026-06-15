---
name: release-registry
description: Release the registry submodule (a leaf consumer) — bump tx3-lang + tx3-tir together and advance the git-rev dep on tx3-lift, then land + pointer-advance.
---

# release-registry

Release the `services/registry` app: a downstream leaf consumer of the toolchain, and one of the two
`services/` grouping members (alongside `publish-docs-site` for `docs`). It carries the **git-rev
trap**: `tracker` pins `tx3-lift` by git rev, so the direct `tx3-tir` pin and the rev must advance
together or the dual-tir conflict returns. Instantiates the umbrella
[`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md).

## When to use
- Invoked by the `release-toolchain` orchestrator after `tooling` published (so `tx3-lift`'s bump commit
  exists to point the git rev at).
- Standalone to bring `registry` up to a released toolchain.

Do not use to publish toolchain crates — `registry` only consumes them.

## Scope
- `services/registry` (one submodule, multiple crates):
  - `services/registry/backend` — pins `tx3-lang`, `tx3-tir` (version pins).
  - `services/registry/tracker` — pins `tx3-tir` (version) **and** `tx3-lift` + `tx3-lift-cardano` by **git rev**.
- `registry` has no crate publish and no semver tags — it deploys via its own Docker/CI infra. The
  "release" here is landing the dep-bump and advancing the umbrella pointer; it produces no manifest
  artifact.

## Inputs
- `upstream_versions` — published `tx3-lang`, `tx3-tir`, and the **merged `tx3-lift` bump commit SHA**
  (from `release-tooling`).
- `target_channel`, `scope`, `bump_policy` per the contract.

## Procedure
1. **Map scope.** `backend` = version-pin consumer; `tracker` = version-pin + git-rev consumer.
2. **Bump pins together (the lockstep):**
   - `backend`: bump `tx3-lang` + `tx3-tir` to the adopted versions in one change.
   - `tracker`: bump `tx3-tir` **and** advance the `tx3-lift` / `tx3-lift-cardano` `rev = ...` to
     `tx3-lift`'s merged bump commit. Confirm that commit is on `tx3-lift`'s `main` (`gh` /
     `git ls-remote`). Advancing the direct `tx3-tir` while the rev still carries old tir reproduces the
     dual-tir failure — move both.
3. **Build** the whole `registry` workspace (`cargo build --workspace`). `DATABASE_URL`-dependent sqlx
   integration tests failing is environmental, not a release blocker — confirm it *compiles*.
4. **Gate — land the dep-bump PR.** State:
   > Merge the `registry` dep-bump PR (`tx3-lang`/`tx3-tir` + `tx3-lift` rev) into `main`, then confirm.

   **Stop and wait.** (No crate/binary publish — registry ships via its own deploy infra.)
5. **Verify.** `registry/main` carries the bumped pins (`gh pr` confirms the merge; squash rewrites SHAs,
   so verify by PR, not SHA).
6. **Report Outputs.**

## Outputs
- `pointers: [ "services/registry" ]`
- (no `crates` / `binaries` — registry publishes none)

## Guardrails
- **Bump `tx3-tir` and the `tx3-lift` git rev together** — the git rev is a version pin carrying its own
  transitive `tx3-tir`; advancing one without the other is the classic dual-tir trap.
- Adopt only the verified-published `tx3-lang`/`tx3-tir` and a `tx3-lift` rev that is actually on
  `tx3-lift`'s `main`.
- Whole-workspace build; treat `DATABASE_URL` integration-test failures as environmental, not blockers.
- registry has no manifest artifact — don't add it to `channel-version-update`.

## Error handling
- **`links to two different versions of tx3-tir`** — `tracker`'s `tx3-lift` rev still carries the old
  tir while `tx3-tir` was bumped directly. Advance the rev to `tx3-lift`'s new-tir commit.
- **The `tx3-lift` rev isn't on `main`** — `release-tooling` hasn't landed `tx3-lift`'s bump yet; hold
  registry until it has (registry runs after tooling for exactly this reason).
- **Submodule `DIVERGED` at finalization** — squash-merge rewrote the SHA; confirm the PR merged via
  `gh pr`, fast-forward to `origin/main`, pin that tip (see `commit-umbrella`).
