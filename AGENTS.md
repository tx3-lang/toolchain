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
- `tooling/` → toolchain binaries and developer tools: `trix`, `tx3up`, `tx3-lsp`, `tx3-mcp`, `tx3-lift`. See [`tooling/AGENTS.md`](./tooling/AGENTS.md).
- `plugins/` → editor, CI, and agent integrations: `vscode-tx3`, `tx3-skills`, `actions`. See [`plugins/AGENTS.md`](./plugins/AGENTS.md).
- `backends/` → transaction execution backends and gateways: `tx3-hydra`, `protocol-gateway`. See [`backends/AGENTS.md`](./backends/AGENTS.md).
- `protocols/` → third-party Tx3 protocol definitions from the `open-tx3` org: `indigo`, `strike`, `bodega`, `fluid`, `vyfi`, `snek-fun`, `acme`, `githoney`. See [`protocols/AGENTS.md`](./protocols/AGENTS.md).

Two submodules and one subtree sit outside the groupings:

- `registry/` → [`tx3-lang/registry`](https://github.com/tx3-lang/registry) — registry of UTxO protocols: Rust backend, TS frontend, on-chain tracker, sample `.tx3` protocol data.
- `docs/` → [`tx3-lang/docs`](https://github.com/tx3-lang/docs) — public docs.
- `sdks/` → the Tx3 SDK fleet: `rust-sdk/`, `web-sdk/`, `go-sdk/`, `python-sdk/` submodules, plus the cross-cutting SDK spec, parity matrix, e2e scripts, and skills. See [`sdks/AGENTS.md`](./sdks/AGENTS.md).

## Routing a change

Route to a grouping, then consult that grouping's `AGENTS.md` for the specific submodule.

- `manifest-*.json` — toolchain component versions per release channel. Use the `channel-version-update` skill.
- `core/` — TII / TIR / TRP wire-format specs. See [`core/AGENTS.md`](./core/AGENTS.md).
- `lang/` — the Tx3 language: parser, type system, codegen, semantics. See [`lang/AGENTS.md`](./lang/AGENTS.md).
- `tooling/` — toolchain binaries and developer tools. See [`tooling/AGENTS.md`](./tooling/AGENTS.md).
- `plugins/` — editor, CI, and agent integrations. See [`plugins/AGENTS.md`](./plugins/AGENTS.md).
- `backends/` — transaction execution backends / gateways. See [`backends/AGENTS.md`](./backends/AGENTS.md).
- `protocols/` — third-party Tx3 protocol definitions from the `open-tx3` org. See [`protocols/AGENTS.md`](./protocols/AGENTS.md).
- `registry/` — UTxO protocol registry application. Backend service (Rust, `backend/`), web frontend (TS, `frontend/`), on-chain tracker (`tracker/`), sample protocol files (`data/*.tx3`), and deployment glue (`bootstrap/`, `docker/`, `zot/`).
- `docs/` — user-facing docs, tutorials, reference, examples.
- `sdks/` — per-language SDKs (rust/web/go/python) and the fleet's spec, parity matrix, e2e scripts, and skills. See [`sdks/AGENTS.md`](./sdks/AGENTS.md).

Every grouping `AGENTS.md`, and any individual submodule's own `AGENTS.md` / `CLAUDE.md` /
`README.md`, overrides this file for work inside that path.

Dependency direction for cross-cutting changes is typically `core/` → `lang/` → `tooling/` → `docs`. `plugins/`, `backends/`, `registry/`, `protocols/`, and `sdks/` are downstream consumers that exercise the toolchain against real protocols; treat them like `docs/` for ordering — bump after the upstream change lands.

## Skills

Skill definitions guide automated agents through common maintenance tasks. Each skill is
documented in `skills/<name>/SKILL.md` with:

- **Purpose:** What the skill accomplishes
- **Prerequisites:** Required tools and setup
- **Context:** Files, formats, and environment expectations
- **Procedure:** Step-by-step execution guide
- **Decision Guidelines:** How to handle common decisions
- **Safety Checks:** Verification steps before/during execution

Available skills:

- `skills/channel-version-update/` — update toolchain component versions by checking GitHub releases and updating the manifest files.
- `skills/publish-docs-site/` — publish the latest Tx3 docs to the company-wide docs site (`docs.txpipe.io`) by triggering the `txpipe/docs` `update-submodules` workflow.
- `skills/commit-umbrella/` — commit the umbrella repo after submodule pointers move, pre-checking that submodules are pushed, track latest `main`, and that grouping `AGENTS.md` routing is up to date.
- `skills/add-language-feature/` — roll out a new Tx3 language feature (operator, expression form, builtin) across every toolchain layer: spec, grammar/AST, analysis/lowering, TIR/reduction, downstream consumers, docs, and agent skills.
- `sdks/skills/` — SDK-fleet skills (`add-sdk-feature`, `audit-parity`, `propagate-change`, `release-synced`, `release-sdk-patch`, `run-e2e-tests`, `scaffold-new-sdk`).

## Scope of this repo

Intentionally minimal: it holds the release manifests, submodule pointers, and orchestration
docs. Do not add a top-level workspace, build script, or language package manifest unless the
user explicitly asks for one — the release `manifest-*.json` files are the only manifests that
belong at the root.
