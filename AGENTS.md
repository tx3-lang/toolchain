# toolchain — agent guide

This repository is the home of the **Tx3 toolchain**. It is both the source of truth for
toolchain release versions and a thin aggregator of the Tx3 toolkit as git submodules, giving
coding agents (and humans) a single entry point for cross-cutting changes.

## Release manifests

The root `manifest-stable.json`, `manifest-beta.json`, and `manifest-nightly.json` files are the
source of truth for the versions of each toolchain component (`tx3c`, `trix`, `tx3-lsp`,
`tx3-mcp`, `dolos`, `cshell`, and `tx3up` itself) shipped on each release channel. On every push
to `main` that touches them, `.github/workflows/release.yml` cuts a GitHub release with the
manifests attached. Keep manifest edits in their own commits.

## Groupings

Real toolkit code lives in git submodules, organized into purpose-named grouping folders.
Each grouping has its own `AGENTS.md` with local, per-submodule routing — open it when
working inside that group.

- `core/` → wire-format specs: `tii`, `tir`, `trp`. See [`core/AGENTS.md`](./core/AGENTS.md).
- `lang/` → the Tx3 language: `tx3`. See [`lang/AGENTS.md`](./lang/AGENTS.md).
- `tooling/` → toolchain binaries and developer tools: `trix`, `tx3up`, `tx3-lsp`, `tx3-mcp`, `tx3-lift`, `cshell`. See [`tooling/AGENTS.md`](./tooling/AGENTS.md).
- `plugins/` → editor, CI, and agent integrations: `vscode-tx3`, `tx3-skills`, `actions`. See [`plugins/AGENTS.md`](./plugins/AGENTS.md).
- `backends/` → TRP backends / runtime infrastructure that executes Tx3 transactions: `tx3-hydra`, `protocol-gateway`, `dolos`. See [`backends/AGENTS.md`](./backends/AGENTS.md).
- `protocols/` → third-party Tx3 protocol definitions from the `open-tx3` org: `indigo`, `strike`, `bodega`, `fluid`, `vyfi`, `snek-fun`, `acme`, `githoney`, `txpipe`. See [`protocols/AGENTS.md`](./protocols/AGENTS.md).
- `services/` → hosted products and surfaces we deploy and operate: `registry`, `docs`. See [`services/AGENTS.md`](./services/AGENTS.md).

One subtree sits outside the groupings:

- `sdks/` → the Tx3 SDK fleet: `rust-sdk/`, `web-sdk/`, `go-sdk/`, `python-sdk/` submodules, plus the cross-cutting SDK spec, parity matrix, e2e scripts, and skills. See [`sdks/AGENTS.md`](./sdks/AGENTS.md).

## Routing a change

Route to a grouping, then consult that grouping's `AGENTS.md` for the specific submodule.

- `manifest-*.json` — toolchain component versions per release channel. Use the `channel-version-update` skill.
- `core/` — TII / TIR / TRP wire-format specs. See [`core/AGENTS.md`](./core/AGENTS.md).
- `lang/` — the Tx3 language: parser, type system, codegen, semantics. See [`lang/AGENTS.md`](./lang/AGENTS.md).
- `tooling/` — toolchain binaries and developer tools. See [`tooling/AGENTS.md`](./tooling/AGENTS.md).
- `plugins/` — editor, CI, and agent integrations. See [`plugins/AGENTS.md`](./plugins/AGENTS.md).
- `backends/` — TRP backends / runtime infrastructure. See [`backends/AGENTS.md`](./backends/AGENTS.md).
- `protocols/` — third-party Tx3 protocol definitions from the `open-tx3` org. See [`protocols/AGENTS.md`](./protocols/AGENTS.md).
- `services/` — hosted products we deploy and operate: the `registry` app (`services/registry/`) and the `docs` site (`services/docs/`). See [`services/AGENTS.md`](./services/AGENTS.md).
- `sdks/` — per-language SDKs (rust/web/go/python) and the fleet's spec, parity matrix, e2e scripts, and skills. See [`sdks/AGENTS.md`](./sdks/AGENTS.md).

Every grouping `AGENTS.md`, and any individual submodule's own `AGENTS.md` / `CLAUDE.md` /
`README.md`, overrides this file for work inside that path.

Dependency direction for cross-cutting changes is typically `core/` → `lang/` → `tooling/` → downstream consumers. `plugins/`, `backends/`, `services/`, `protocols/`, and `sdks/` consume the toolchain — bump them after the upstream change lands; within `services/`, the `docs` site publishes last.

## Skills

Skill definitions guide automated agents through common maintenance tasks. Each skill is
documented in `skills/<name>/SKILL.md` with:

- **Purpose:** What the skill accomplishes
- **Prerequisites:** Required tools and setup
- **Context:** Files, formats, and environment expectations
- **Procedure:** Step-by-step execution guide
- **Decision Guidelines:** How to handle common decisions
- **Safety Checks:** Verification steps before/during execution

A cross-cutting release is split along the grouping boundaries: `skills/release-toolchain/` is the
**orchestrator**, and each grouping owns its own release sub-procedure (distributed under
`<grouping>/skills/`, like `sdks/skills/`). The uniform contract every grouping skill instantiates is
`skills/release-toolchain/grouping-contract.md`.

Umbrella-level skills (top-level `skills/`):

- `skills/release-toolchain/` — **orchestrator** for a cross-cutting toolchain release: detect which groupings have pending work, run each grouping's release skill in dependency order (`core → lang → sdks → tooling → {plugins, backends, registry} → protocols → docs`; `registry` & `docs` live in `services/`), thread published versions forward, and finalize via `commit-umbrella` → `channel-version-update` → `publish-docs-site`. Per-submodule publish mechanics live in the grouping skills, not here.
- `skills/commit-umbrella/` — commit the umbrella repo after submodule pointers move, pre-checking that submodules are pushed, track latest `main`, and that grouping `AGENTS.md` routing is up to date.
- `skills/channel-version-update/` — update toolchain component versions by checking GitHub releases and updating the manifest files.
- `skills/add-language-feature/` — roll out a new Tx3 language feature (operator, expression form, builtin) across every toolchain layer: spec, grammar/AST, analysis/lowering, TIR/reduction, downstream consumers, docs, and agent skills.
- `skills/add-e2e-journey/` — add a journey to the umbrella DX e2e harness (`e2e/`); the canonical guide for the journey contract and the `lib/common.sh` helper API.

Per-grouping release skills (distributed under each grouping, like `sdks/skills/`):

- `core/skills/release-core/` — publish the `tx3-tir` crate; `tii`/`trp` pointer-advance only.
- `lang/skills/release-lang/` — publish `tx3-lang`/`tx3-cardano`/`tx3-resolver` + the `tx3c` binary.
- `tooling/skills/release-tooling/` — `tx3-lsp`/`tx3-mcp`/`trix`/`tx3up`/`tx3-lift` releases + the `trix` compat floor.
- `plugins/skills/release-plugins/` — marketplace publishes for `vscode-tx3`/`tx3-skills`/`actions`.
- `backends/skills/release-backends/` — flag-and-defer lag report for `tx3-hydra`/`protocol-gateway` (deploy-only).
- `protocols/skills/verify-protocols/` — verify `.tx3` fixtures against the new toolchain (no release).
- `services/skills/` — `release-registry/` (release the registry app: `tx3-lang`+`tx3-tir` bump + `tx3-lift` git-rev advance) and `publish-docs-site/` (publish the docs site to `docs.txpipe.io`).
- `sdks/skills/` — SDK-fleet skills (`add-sdk-feature`, `audit-parity`, `propagate-change`, `release-synced`, `release-sdk-patch`, `run-e2e-tests`, `scaffold-new-sdk`).

## Scope of this repo

Intentionally minimal: it holds the release manifests, submodule pointers, and orchestration
docs. Do not add a top-level workspace, build script, or language package manifest unless the
user explicitly asks for one — the release `manifest-*.json` files are the only manifests that
belong at the root.
