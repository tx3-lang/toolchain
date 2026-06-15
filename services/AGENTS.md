# services — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `services/` grouping holds the **hosted
products and surfaces** that Tx3 deploys and operates — things end users *visit*, as opposed to tools
they install (`tooling/`) or the runtime TRP infrastructure that executes transactions (`backends/`).
Each ships via its own deploy pipeline and is **not** tracked in the channel manifests. They are
downstream consumers — bump them after upstream changes in `core/`, `lang/`, and `tooling/` have landed.

## Routing a change

- `services/registry/` → [`tx3-lang/registry`](https://github.com/tx3-lang/registry) — UTxO protocol registry application: Rust backend (`backend/`), TS frontend (`frontend/`), on-chain tracker (`tracker/`), sample protocol files (`data/*.tx3`), and deploy glue (`bootstrap/`, `docker/`, `zot/`).
- `services/docs/` → [`tx3-lang/docs`](https://github.com/tx3-lang/docs) — user-facing docs, tutorials, reference, and examples; published to `docs.txpipe.io`.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.

## Skills

- `services/skills/release-registry/` — release the `registry` app (a leaf consumer): bump `tx3-lang` + `tx3-tir` together and advance the git-rev dep on `tx3-lift`, then land the dep-bump and pointer-advance (registry publishes no crate/binary; it deploys via its own infra). Instantiates the umbrella `grouping-contract.md`; invoked by the `release-toolchain` orchestrator or run standalone.
- `services/skills/publish-docs-site/` — publish the latest Tx3 docs to `docs.txpipe.io` by triggering the `txpipe/docs` three-stage pipeline (Update Submodules → Build → Deploy) and verifying the render. Invoked at the orchestrator's finalization step (docs runs last) or run standalone.
