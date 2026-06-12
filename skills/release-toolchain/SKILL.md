# Release Toolchain Skill

## Purpose
Orchestrate a **cross-cutting toolchain release** — a change that originates in an upstream
crate (`core/tir`, `lang/tx3`) and must ripple through every downstream consumer that pins it
via crates.io — interactively, in lockstep with the developer who performs the actual
`crates.io` publishes. This skill is the conductor: it sequences the dependency waves, pauses
at each **publish gate** for the developer to cut the release, then bumps the next wave's
dependency pins, and finishes by moving submodule pointers and the `trix` version floor. It was
battle-tested by the parametric-tuple rollout (tir `0.18.0` → tx3-lang `0.22.0` + siblings →
lsp/mcp/registry → trix floor → umbrella).

It complements the other skills rather than replacing them:
- **`add-language-feature`** lands the *code* across submodules (one PR each). Run it first.
- **`release-toolchain`** (this) sequences *publishing* those merged crates and bumping the
  pins that connect them. Run it after the feature PRs are merged.
- **`commit-umbrella`** is the final wave (submodule-pointer commit) — invoked from here.
- **`channel-version-update`** ships the resulting *binaries* to a release channel — a
  separate, later step once the tools cut GitHub releases.

## Prerequisites
- Run from the umbrella repo root with submodules initialized (`git submodule update --init`).
- The feature/fix code is already **merged** into each affected submodule's `main` (that's
  `add-language-feature`'s job). This skill releases what is merged; it does not write feature code.
- `cargo` for building/verifying each Rust workspace; `gh` authenticated for PR/merge checks.
- **The developer publishes to crates.io**, not the agent. The agent prepares dep bumps and
  verifies builds; it stops at each publish gate and waits for the developer's "published vX" signal.

## Context

### The crates.io dependency graph (what pins what)
Submodules are independent repos depending on each other by **published crates.io version**, not
path deps. A release wave = the set of crates that can publish once their upstream pin is available.

```
core/tir  (tx3-tir)
   │  pinned by ↓
lang/tx3      (tx3-lang, tx3-cardano, tx3-resolver)   ── also: registry, tooling/tx3-lift pin tx3-tir directly
   │  pinned by ↓
tooling/tx3-lsp, tooling/tx3-mcp, registry            ── pin tx3-lang (and often tx3-tir transitively)
   │  gated by ↓
tooling/trix  ([toolchain] floor + COMPAT_MATRIX)     ── version-gates the produced TIR; no crate dep
   │  recorded by ↓
umbrella submodule pointers  →  manifest-*.json (binaries, later, separate channel release)
```

Verify the real pins before sequencing — grep, don't assume:
```bash
grep -rn 'tx3-tir\s*=\|tx3-lang\s*=' --include=Cargo.toml core lang tooling registry
```

### Semver reality for 0.x crates — the central hazard
**Every `0.x.y` minor bump is breaking** (cargo treats `^0.17` and `0.18` as incompatible). This
makes a tir bump a *flag-day* for its consumers:
- You **cannot** half-bump. If consumer C directly pins `tx3-tir = 0.18` but still pins a
  *published* `tx3-lang` that itself pins `tx3-tir = ^0.17`, cargo must resolve two incompatible
  tirs in one tree → it fails. **Hold C until `tx3-lang` is republished against the new tir**, then
  bump both pins in C together.
- **Transitive pins via git-rev deps are a trap.** A consumer that pins a sibling by git rev
  (e.g. `registry/tracker` → `tx3-lift` at rev `abc123`) drags in *that rev's* tir. Bumping the
  consumer's direct tir while the git-rev still carries old tir reproduces the dual-tir conflict.
  Advance the git rev to the sibling's merged bump commit as part of the same wave.

### Publish gates are developer actions
The agent never runs `cargo publish`. Each wave ends at a gate where the developer (or CI-on-tag)
publishes the wave's crates. The skill's job at a gate: state exactly **which crates, which
versions** to publish, then **stop and wait**. The developer's reply ("published tx3-tir 0.18",
"sibling crates published") is the signal to start the next wave's dep bumps.

### Verifying an un-published wave: patch, build, revert
To confirm a downstream crate *will* build against an upstream that isn't on crates.io yet, use a
temporary `[patch.crates-io]` path override (depth-adjusted per crate), build, then revert **both**
`Cargo.toml` and `Cargo.lock` individually. Never commit a patch or lockfile churn. (Full mechanics
in `add-language-feature`'s "Cross-repo dependency model".) The compile is the safety net for
exhaustive-match breaks — and a `-p <single-crate>` build can **miss** a sibling binary's broken
match (the tuple rollout's `bin/tx3c` arm surfaced only on a full-workspace build); build the
**whole workspace** of each consumer, not just the changed package.

## Procedure

### 0. Map the release and confirm the plan with the developer
1. Identify the originating change and the **lowest** crate it modifies (usually `tx3-tir` or
   `tx3-lang`). Grep the pin graph (above) to enumerate every downstream consumer.
2. Decide each crate's **new version** with the developer (0.x minor for a breaking schema add;
   patch only for a truly compatible fix — rare across the tir boundary).
3. Lay out the waves as a table and get a go-ahead. Example (tuple rollout):

   | Wave | Crates | Publishes | Then bump |
   | --- | --- | --- | --- |
   | 1 | `tx3-tir` | → 0.18.0 | tir pin in lang/tx3, registry, tx3-lift |
   | 2 | `tx3-lang`,`tx3-cardano`,`tx3-resolver` | → 0.22.0 | tx3-lang pin in lsp/mcp/registry |
   | 3 | (consumers don't publish libs) | — | lsp/mcp/registry dep bumps land |
   | 4 | `trix` | floor → 0.22.0 | `[toolchain]` + COMPAT_MATRIX |
   | 5 | umbrella | pointers | commit-umbrella |

### 1. Wave 1 — release the root crate (e.g. `tx3-tir`)
1. Confirm the root crate's `main` carries the merged change and its `Cargo.toml` version is the
   target (bump it in a small PR if not — that PR is part of `add-language-feature`, not this skill).
2. **Gate:** tell the developer *"publish `tx3-tir 0.18.0` to crates.io, then confirm."* **Stop.**
3. On confirmation, proceed to Wave 2.

### 2. Wave 2 — bump the pin, land + release the next layer (`tx3-lang` & siblings)
1. In every crate that *directly* pins the just-published crate (`lang/tx3` workspace: tx3-lang,
   tx3-cardano, tx3-resolver; plus `registry`, `tooling/tx3-lift`), update the pin to the new
   version. Bump the crates' **own** versions where they also re-publish (tx3-lang 0.21→0.22).
2. Verify each builds (full workspace) against the now-published upstream — no patch needed once
   it's on crates.io; if you're ahead of the publish, use the patch-build-revert dance.
3. Land these dep-bump commits (PRs, squash-merged). Note in each PR body: *"depends on tx3-tir
   0.18 (published); release after merge."*
4. **Gate:** tell the developer *"publish `tx3-lang`, `tx3-cardano`, `tx3-resolver` 0.22.0."* **Stop.**

### 3. Wave 3 — bump the leaf consumers (`tx3-lsp`, `tx3-mcp`, `registry`)
1. Now that `tx3-lang` is published against the new tir, bump **both** `tx3-lang` and (if directly
   pinned) `tx3-tir` in the leaf consumers **together** — this resolves the dual-tir hazard.
2. For any consumer pinning a sibling by **git rev**, advance the rev to that sibling's merged
   bump commit (`registry/tracker` → `tx3-lift` new rev). Confirm the rev is on the sibling's `main`.
3. Build each consumer's **whole workspace**. Environmental test failures (e.g. `DATABASE_URL must
   be set` for sqlx integration tests) are not release blockers — distinguish them from compile
   breaks and say so. Pre-existing, unrelated breakage (e.g. an upstream protobuf drift) is **out
   of scope**: document it in the PR, don't fix it here.
4. Land the consumer dep-bump PRs.

### 4. Wave 4 — raise the `trix` version floor
The TIR schema addition is **forward-incompatible** (a pre-bump reader hits `unknown variant`).
The gate that protects users is `trix`'s version check, in two places:
1. `tooling/trix/src/spawn/compat.rs` — raise `COMPAT_MATRIX` `tx3c { min }` to the producing
   release (e.g. `0.22.0`) and update the rationale comment to name the new feature/variant.
2. Projects pin their own floor in `trix.toml [toolchain] tx3c` (a lower bound only). The matrix
   is the global default. Decide with the developer whether this release moves the global floor.
3. `cargo test -p trix` (the `evaluate`/`collect_project_mins` unit tests gate this). Land the PR.

### 5. Wave 5 — move umbrella pointers
Hand off to **`commit-umbrella`**: it runs the three pre-flight checks (pushed / tracks-latest-main
/ routing), repins each moved submodule to its `origin/main` tip (remember: squash-merge rewrites
SHAs, so `DIVERGED` is confirmed via `gh pr`, not SHA matching), and commits the pointer bump on the
staging branch. Stage only the submodules this release moved; leave unrelated drift (other behind
backends, stray `AGENTS.md` edits) untouched and surface it.

### 6. (Later, separate) ship binaries to a channel
Releasing the *crates* does not ship the *tools* to users. When the binaries (`tx3c`, `trix`,
`tx3-lsp`, `tx3-mcp`) cut their own GitHub releases, use **`channel-version-update`** to bump
`manifest-*.json`. That's a distinct, developer-initiated step — mention it as the natural
follow-up; don't fold it into this release without being asked.

## Decision Guidelines
- **Never publish for the developer.** State the crates+versions for each gate and wait. Publishing
  is irreversible and outward-facing.
- **Bump consumers of a 0.x crate in lockstep, not piecemeal.** A consumer that pins both
  `tx3-lang` and `tx3-tir` must move both in one commit *after* `tx3-lang` republishes — bumping
  one early guarantees a dual-version resolve failure.
- **Treat git-rev deps as version pins.** They carry a transitive crate graph; advancing the direct
  pin without advancing the rev re-introduces the conflict.
- **Verify merge state via `gh pr`, not SHA** when repinning submodules — squash-merge gives every
  merged branch a fresh SHA (see `commit-umbrella`).
- **Patch-build-revert to verify ahead of a publish; never commit the patch or lockfile churn.**
- **Distinguish compile breaks from environmental/pre-existing failures.** Only the former block a
  wave. Name the latter to the developer and keep them out of scope.
- **Scope the umbrella commit to this release's submodules.** Don't fast-forward unrelated drift.

## Safety Checks
- [ ] Wave order respects the pin graph: root crate published *before* any consumer bumps its pin.
- [ ] No consumer was bumped while still pinning a published upstream that carries the old (incompatible) transitive version — dual-version resolves were avoided.
- [ ] Git-rev deps advanced to the sibling's merged bump commit (rev confirmed on `main`).
- [ ] Each consumer's **whole workspace** compiled (not just `-p` the changed crate) — exhaustive-match breaks in sibling binaries caught.
- [ ] Every temporary `[patch.crates-io]` and `Cargo.lock` change reverted before committing.
- [ ] `trix` floor (`COMPAT_MATRIX` + rationale comment) raised to the producing release; `cargo test -p trix` green.
- [ ] Umbrella pointers moved via `commit-umbrella` (its three checks passed); only this release's submodules staged.
- [ ] Each publish was performed by the developer at an explicit gate, not by the agent.

## Error Handling
- **`failed to select a version … links to two different versions of tx3-tir`** — the dual-tir
  conflict: a consumer pins new tir directly while a published `tx3-lang` (or a git-rev sibling)
  still pins old tir. Hold the consumer until `tx3-lang` republishes, then bump both pins together;
  advance any git-rev sibling to its new-tir commit.
- **`unknown variant <X>` / wrong-arity decode at runtime** — a pre-bump reader met new TIR.
  Expected forward-incompat; the fix is the `trix` floor bump (Wave 4), not a code change.
- **Exhaustive-match compile error surfaces only on full build** — you built `-p <crate>` and missed
  a sibling binary's match arm. Rebuild the whole workspace of every consumer.
- **`DATABASE_URL must be set` / other env-dependent test failure** — environmental, not a release
  blocker. Confirm the crate *compiles*; note the skipped integration tests to the developer.
- **Pre-existing unrelated breakage in a consumer (e.g. upstream protobuf drift)** — out of scope.
  Document in the PR; do not fix it inside the release.
- **Submodule reports `DIVERGED` at the umbrella step** — squash-merge rewrote the SHA. Confirm the
  PR merged via `gh pr`, fast-forward the submodule to `origin/main`, pin that tip (see `commit-umbrella`).
