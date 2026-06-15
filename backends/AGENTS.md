# backends — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `backends/` grouping holds the **TRP
backends** — runtime infrastructure that executes Tx3 transactions against specific environments.
They are tool-like (often third-party, not necessarily deployed by us) but meant for *runtime*, unlike
the development tools in `tooling/` or the hosted surfaces we operate in `services/`. These are
downstream consumers — bump them after upstream changes in `core/`, `lang/`, and `tooling/` have landed.

## Routing a change

- `backends/tx3-hydra/` → [`tx3-lang/tx3-hydra`](https://github.com/tx3-lang/tx3-hydra) — Tx3 execution backend for Hydra state channels.
- `backends/protocol-gateway/` → [`tx3-lang/protocol-gateway`](https://github.com/tx3-lang/protocol-gateway) — API layer / gateway service for Cardano protocols built with Tx3.
- `backends/dolos/` → [`txpipe/dolos`](https://github.com/txpipe/dolos) — Cardano data node used as a Tx3 execution backend.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.

## Skills

- `backends/skills/release-backends/` — **flag-and-defer** check for the `backends/` grouping: report how far `tx3-hydra` / `protocol-gateway` lag the released toolchain (deploy-on-branch services with no semver tags — it does **not** auto-bump them); `dolos` is third-party adopt-only. Instantiates the umbrella `grouping-contract.md`; invoked by the `release-toolchain` orchestrator or run standalone.
