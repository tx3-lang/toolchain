# backends — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `backends/` grouping holds
**transaction execution backends and gateways** that run Tx3 protocols against specific
environments. These are downstream consumers — bump them after upstream changes in `core/`,
`lang/`, and `tooling/` have landed.

## Routing a change

- `backends/tx3-hydra/` → [`tx3-lang/tx3-hydra`](https://github.com/tx3-lang/tx3-hydra) — Tx3 execution backend for Hydra state channels.
- `backends/protocol-gateway/` → [`tx3-lang/protocol-gateway`](https://github.com/tx3-lang/protocol-gateway) — API layer / gateway service for Cardano protocols built with Tx3.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.
