# Grouping release contract

Normative contract that every per-grouping release skill (`release-core`, `release-lang`,
`release-tooling`, `release-plugins`, `release-backends`, `release-registry`) instantiates, and that
the `release-toolchain` orchestrator relies on to compose them. Read this first when authoring or
running a grouping skill — it is to the grouping skills what `sdks/sdk-spec/release-policy.md` is to the
SDK fleet skills.

A grouping skill releases the pending work **inside one grouping**. It adopts the versions its
upstream groupings already published, bumps only its *intra-grouping* pins, verifies, gates on the
developer's publish/tag, and reports what it produced. It never reasons about the global wave order —
that is the orchestrator's job.

## The structural invariant

`upstream_versions` only ever contains **already-published** artifacts. The orchestrator runs groupings
in dependency order and does not start a downstream grouping until the upstream grouping's publish gate
has closed and been verified. Therefore a grouping skill can never bump a pin to an unpublished
upstream — the 0.x "dual-version resolve" hazard is avoided *by construction*, not by manual lockstep
reasoning. If you ever find a grouping skill computing a version that isn't yet on crates.io / a
released tag, the contract has been violated.

## Required skill sections (fixed order)

YAML frontmatter (`name`, `description`) then:

`When to use / Do not use` · `Scope` · `Inputs` · `Procedure` · `Outputs` · `Guardrails` ·
`Error handling`. (Modeled on the SDK fleet skills.)

## Inputs

- **`target_channel`** — `stable` | `beta` | `nightly`. Informs version policy and is passed through to
  the manifest step. Defaults to `beta` when run standalone.
- **`upstream_versions`** — map of already-published artifacts this grouping may adopt, e.g.
  `{ "tx3-tir": "0.18.0", "tx3-lang": "0.22.0", "tx3c": "0.22.0", "tx3-sdk": "0.11.0" }`. The orchestrator
  fills it from upstream groupings' `Outputs`. Empty when the grouping has no upstream (e.g. `core`).
- **`scope`** — the subset of this grouping's submodules with pending releasable work. Orchestrator-
  detected, or user-given for a standalone run. **A skill must accept an empty scope and no-op.**
- **`bump_policy`** — optional per-submodule version overrides. Default: compute from semver intent —
  a breaking schema/API change is a 0.x **minor** bump (every 0.x minor is breaking); a truly
  compatible fix is a patch.

## Procedure (uniform skeleton — each skill specializes step 2 and 4)

1. **Map + classify scope.** Read the grouping `AGENTS.md` and this contract. For each in-scope
   submodule, classify it: `crate-publish` · `binary-dist` · `crate+binary` · `floor-only` ·
   `pointer-only` · `third-party-adopt`. **Grep the real pins, never assume:**
   `grep -rn 'tx3-tir\s*=\|tx3-lang\s*=\|tx3-sdk\s*=' --include=Cargo.toml <grouping>`.
2. **Bump intra-grouping pins.** Set each in-scope submodule's pins to the `upstream_versions` values;
   bump the submodule's own version where it republishes; advance any git-rev sibling dep to its merged
   commit; move version floors where applicable. Only intra-grouping edges are touched here — cross-
   grouping adoption already arrived via `upstream_versions`.
3. **Verify the whole workspace builds.** `cargo build --workspace` (or the grouping's native build) —
   **never `-p <crate>`**: a single-package build misses exhaustive-match breaks in sibling binaries. If
   building ahead of a publish, use a temporary `[patch.crates-io]` path override, build, then revert
   **both** `Cargo.toml` and `Cargo.lock` individually — never commit the patch or lockfile churn.
   Distinguish compile breaks (blockers) from environmental failures (e.g. `DATABASE_URL` for sqlx
   integration tests) and pre-existing unrelated drift (surface, don't block, don't fix here).
4. **Developer publish/tag gate.** State exactly which submodules, which crates/binaries, which
   versions, and the exact action (`cargo publish` / `cargo release <v>` / push tag `v<x.y.z>` /
   `vsce publish` / move `vN` tag …). **Then stop and wait.** The agent never publishes, tags, or moves
   marketplace artifacts — those are irreversible, outward-facing developer actions.
5. **Verify the gate completed.** Confirm the crate is on crates.io (sparse index
   `https://index.crates.io/<a>/<b>/<crate>`) and/or the tag/release exists
   (`gh release view --repo <owner>/<repo> <tag>`) before emitting `Outputs`. `third-party-adopt`
   submodules skip this — they are adopt-only.
6. **Report `Outputs`** in the form below.

## Outputs (the thread the orchestrator reads)

```
crates:   { "<crate>": "<version>" }    # published to crates.io this run
binaries: { "<binary>": "<tag>" }       # tagged / GH-released this run
floors:   { "<tool>": "<min>" }         # version floors raised (e.g. trix COMPAT_MATRIX tx3c min)
pointers: [ "<grouping>/<submodule>" ]  # submodules whose main advanced (for commit-umbrella)
adopted:  { "<artifact>": "<version>" } # third-party upstreams adopted, not produced
skipped:  [ { submodule, reason } ]     # no-op / out-of-scope / env-failure / flagged-and-deferred
```

The orchestrator merges each grouping's `crates` + `binaries` + `floors` into the running
`upstream_versions` for the next grouping, accumulates `pointers` for `commit-umbrella`, and drives
`channel-version-update` from `binaries` + `adopted`.

## Guardrails (apply to every grouping skill)

- **Never publish for the developer.** Skills end at a gate; the developer (or CI-on-tag) publishes.
- **Adopt only published upstreams.** Every `upstream_versions` entry must be verified-published before
  you bump a pin to it (the structural invariant).
- **Bump 0.x consumers in lockstep within the grouping.** A submodule pinning both `tx3-lang` and
  `tx3-tir` moves both in one commit, after both are published.
- **Treat git-rev deps as version pins.** Advance the rev to the sibling's merged commit, or the dual-
  version conflict returns.
- **Whole-workspace build, never `-p`.** Revert every temporary patch and lockfile change before any
  commit.
- **Keep manifest edits out of grouping skills.** Manifest bumps belong to `channel-version-update`,
  pointer commits to `commit-umbrella` — both run at the orchestrator's finalization step.
