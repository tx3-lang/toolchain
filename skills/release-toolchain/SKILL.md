# Release Toolchain Skill

## Purpose
Orchestrate a **cross-cutting toolchain release** — a change that originates upstream (`core/tir`,
`lang/tx3`) and must ripple through every downstream grouping that consumes it. This skill is a **pure
conductor**: it detects which groupings have pending releasable work, runs each grouping's own release
sub-procedure in dependency order, threads the just-published versions forward as the next grouping's
inputs, and finishes with the umbrella-level steps (pointers, manifest, docs). It does **not** know how
any individual submodule publishes — that lives in the per-grouping skills.

The decomposition follows the repo's folder groupings, which are its natural release layers. Each
grouping owns a release skill that instantiates the uniform `grouping-contract.md`:

| Grouping | Skill | Location |
| --- | --- | --- |
| core | `release-core` | `core/skills/` |
| lang | `release-lang` | `lang/skills/` |
| sdks | `release-synced` / `release-sdk-patch` | `sdks/skills/` (adapter — see below) |
| tooling | `release-tooling` | `tooling/skills/` |
| plugins | `release-plugins` | `plugins/skills/` |
| backends | `release-backends` | `backends/skills/` (flag-and-defer) |
| protocols | `verify-protocols` | `protocols/skills/` (verify-only, no publish) |
| services | `release-registry` (registry) · `publish-docs-site` (docs) | `services/skills/` |

It complements the other skills rather than replacing them:
- **`add-language-feature`** lands the *code* across submodules (one PR each). Run it first.
- **`release-toolchain`** (this) sequences the grouping releases of that merged code.
- **`commit-umbrella`** and **`channel-version-update`** are the finalization steps — invoked from here.

## Prerequisites
- Run from the umbrella repo root with submodules initialized (`git submodule update --init`).
- The feature/fix code is already **merged** into each affected submodule's `main` (that's
  `add-language-feature`'s job). This skill releases what is merged; it does not write feature code.
- `cargo` for building/verifying each Rust workspace; `gh` authenticated for PR/merge/release checks.
- **The developer publishes / tags / moves marketplace artifacts**, never the agent. Each grouping
  skill stops at a gate and waits for the developer's "done" signal.

## Context

### The dependency graph (what the order encodes)
Submodules are independent repos depending on each other by **published artifact version** (crates.io
crate, released binary tag), not path deps. Releasing flows along the grouping dependency direction:

```
core      (tx3-tir)
  │
lang      (tx3-lang, tx3-cardano, tx3-resolver, + tx3c binary)
  │
sdks      (tx3-sdk)                      ── consumed by tx3-lift & tx3-mcp, so it precedes tooling
  │
tooling   (tx3-lsp, tx3-lift crates; trix/tx3-mcp/tx3-lsp/tx3up binaries; trix COMPAT_MATRIX floor)
  │
  ├── plugins           (vscode-tx3, tx3-skills, actions — soft compat only)
  ├── backends          (tx3-hydra, protocol-gateway — flag-and-defer; dolos third-party)
  └── services/registry (pins tx3-lang + tx3-tir + git-rev to tx3-lift)
        │
  protocols (verify .tx3 against the new toolchain) → services/docs (publish-docs-site, runs last)
```

### Semver reality for 0.x crates — why the order matters
**Every `0.x.y` minor bump is breaking** (cargo treats `^0.17` and `0.18` as incompatible). A consumer
that pins both an upstream crate *and* its transitive dep must bump them together, *after* the upstream
republishes — bump one early and cargo fails with `links to two different versions`. In the old
monolithic skill this was a manual hazard re-derived every release. **Here it is structural:** because
the orchestrator runs groupings in dependency order and never starts a downstream grouping until the
upstream grouping's publish gate has closed and been verified, `upstream_versions` only ever carries
*already-published* artifacts. A grouping skill therefore cannot bump a pin to an unpublished upstream.
The contract (`grouping-contract.md`) states this invariant; this skill enforces it by sequencing.

### Publish gates are developer actions
The agent never runs `cargo publish`, pushes a tag, or moves a marketplace artifact. Each grouping
skill ends at a gate that states exactly which artifacts at which versions to publish, then stops. The
developer's reply ("published / tagged X") is the signal for the orchestrator to verify and proceed.

### The uniform grouping contract
Every grouping skill takes `{ target_channel, upstream_versions, scope, bump_policy }`, runs the
6-step procedure (map → bump intra-grouping pins → whole-workspace build → developer gate → verify →
report), and returns `{ crates, binaries, floors, pointers, adopted, skipped }`. The full spec is in
[`grouping-contract.md`](./grouping-contract.md). The orchestrator composes these blindly — it only
reads the contract's Inputs/Outputs, not each grouping's internal mechanics.

## Procedure

### 0. Detect pending releasable work per grouping
For each grouping, decide whether it has scope. Detection must be **grouping-type aware**:
- cargo-dist / crate repos (`core/tir`, `lang/tx3`, `tooling/*`): compare the latest release
  tag against `main` — commits ahead ⇒ pending; also flag pins lagging the about-to-publish upstreams.
- spec / pointer / deploy repos (`core/tii`, `core/trp`, `plugins/*`, `services/registry`,
  `services/docs`): `main` advanced past the umbrella pointer ⇒ pending (they have no release tags).
  Also flag `services/registry` pins lagging the about-to-publish upstreams.
- adopt-only / deploy-only repos (`tooling/cshell`, `backends/dolos`, `backends/{tx3-hydra,
  protocol-gateway}`): never auto-detect as a *publish* — adopt upstream / flag-and-defer only.

Produce a `pending` map keyed by grouping; empty groupings are skipped.

### 1. Order the groupings
Use the fixed topological order — the groupings are fixed, so this is not a computed DAG:

```
core → lang → sdks → tooling → { plugins, backends, registry } → protocols → docs
```

`sdks` runs **before** `tooling` because `tooling/tx3-lift` and `tooling/tx3-mcp` pin `tx3-sdk`.
`registry` and `docs` both live in `services/` and are sequenced individually — `registry` right after
`tooling`, `docs` (via `publish-docs-site`) dead last.

### 2. Confirm the wave plan with the developer
Render a table — one row per in-scope submodule: grouping, submodule, current → target version, gate
action — and get a go-ahead before invoking any grouping skill. This is the single confirmation point
that replaces the old per-crate-wave table.

### 3. Run each grouping skill in order, threading versions
Initialize `upstream_versions = {}`. For each grouping in topological order with non-empty scope:
1. Invoke `release-<grouping>` with `{ target_channel, upstream_versions, scope, bump_policy }`.
2. It runs its own procedure and stops at its developer gate; the developer publishes/tags; it verifies.
3. On return, **merge** its `crates` + `binaries` + `floors` into `upstream_versions`, and accumulate
   its `pointers` and `adopted` into the run-wide totals.

Because each grouping's gate closes (and is verified) before the next grouping starts, no downstream
pin is ever bumped to an unpublished upstream.

### 4. Adapter hand-offs (groupings that aren't uniform-contract instances)
- **sdks** — the fleet skills take a `MAJOR.MINOR` train, not the contract's Inputs map. If the SDKs need
  a coordinated bump for this release, invoke `sdks/skills/release-synced` (or `release-sdk-patch` for a
  single SDK); otherwise just record the already-published `tx3-sdk` version into `upstream_versions`.
- **backends** — `release-backends` is **flag-and-defer**: it reports how far `tx3-hydra` /
  `protocol-gateway` lag the adopted upstreams and does **not** auto-bump them; `dolos` is third-party
  adopt-only. No publish gate.
- **protocols** — `verify-protocols` re-checks the `open-tx3` `.tx3` files against the new `tx3c`/`trix`
  and reports breakages; it releases nothing.
- **docs** — defer to `publish-docs-site` at finalization if docs moved.

### 5. Finalize (umbrella-level — each its own commit)
1. **`commit-umbrella`** with the accumulated `pointers`: it runs the three pre-flight checks (pushed /
   tracks-latest-main / routing), repins each moved submodule to its `origin/main` tip (squash-merge
   rewrites SHAs, so confirm merges via `gh pr`, not SHA), and commits the pointer bump. Stage **only**
   this release's submodules; surface unrelated drift, don't fast-forward it.
2. **`channel-version-update`** for the manifest binaries (`tx3c`, `trix`, `tx3-lsp`, `tx3-mcp`,
   `dolos`, `cshell`, `tx3up`), driven from the run's `binaries` + `adopted`. Note `tx3c` maps to
   `repo_owner=tx3-lang, repo_name=tx3`. Keep the manifest edit in its own commit.
3. **`publish-docs-site`** if docs moved.

## Decision Guidelines
- **Conduct; don't reimplement.** Per-submodule publish mechanics live in the grouping skills. If you
  are editing a `Cargo.toml` pin or a `COMPAT_MATRIX` from this skill, you've reached too far down — that
  belongs in `release-<grouping>`.
- **Order is the safety mechanism.** Never run a downstream grouping before its upstream grouping's gate
  has closed and verified. The order *is* the lockstep guarantee.
- **Never publish for the developer.** Each grouping skill states its gate and waits.
- **Scope the finalization to this release.** `commit-umbrella` stages only moved submodules; the
  manifest edit lists only bumped binaries.
- **sdks / docs / protocols / backends are not uniform instances** — invoke them via their adapters
  (step 4), don't force them into the contract.

## Safety Checks
- [ ] Pending work detected per grouping with type-aware heuristics; empty groupings skipped.
- [ ] Groupings run in the fixed order `core → lang → sdks → tooling → {plugins, backends, registry} → protocols → docs`.
- [ ] `upstream_versions` only ever held verified-published artifacts when a grouping skill consumed it (the structural invariant).
- [ ] Each grouping skill's publish gate was performed by the developer and verified before the next grouping ran.
- [ ] `commit-umbrella` ran with the accumulated pointers (its three checks passed); only this release's submodules staged.
- [ ] `channel-version-update` bumped only the manifest binaries that actually released (from `binaries` + `adopted`); its own commit.
- [ ] `publish-docs-site` run iff docs moved.

## Error Handling
- **A grouping skill wants to bump a pin to an unpublished upstream** — the structural invariant is
  violated: an upstream gate hasn't actually closed. Stop, verify the upstream publish, fix the order.
- **`failed to select a version … links to two different versions of tx3-tir`** — a downstream grouping
  ran before its upstream republished, or a git-rev sibling still carries old tir. Should be impossible
  if the order held; if it appears, an out-of-order or git-rev pin slipped through (see `release-registry`).
- **Submodule reports `DIVERGED` at finalization** — squash-merge rewrote the SHA. Confirm the PR merged
  via `gh pr`, fast-forward to `origin/main`, pin that tip (see `commit-umbrella`).
- **A grouping has no release mechanism for its pending work** (spec-only, deploy-only) — that's
  expected: `core/tii`/`trp` are pointer-only, backends are flag-and-defer, protocols are verify-only.
  Don't invent a publish gate for them.
