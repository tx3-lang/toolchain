# protocols — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `protocols/` grouping holds
**third-party Tx3 protocol definitions** maintained under the [`open-tx3`](https://github.com/open-tx3)
organization. Each submodule is a team's repository of `.tx3` protocol files mirroring an
on-chain Cardano protocol, used as real-world fixtures for the toolchain.

## Routing a change

- `protocols/indigo/` → [`open-tx3/indigo-protocols`](https://github.com/open-tx3/indigo-protocols) — Indigo protocol Tx3 definitions.
- `protocols/strike/` → [`open-tx3/strike-protocols`](https://github.com/open-tx3/strike-protocols) — Strike Finance protocol Tx3 definitions.
- `protocols/bodega/` → [`open-tx3/bodega-protocols`](https://github.com/open-tx3/bodega-protocols) — Bodega protocol Tx3 definitions.
- `protocols/fluid/` → [`open-tx3/fluid-protocols`](https://github.com/open-tx3/fluid-protocols) — Fluid Tokens protocol Tx3 definitions.
- `protocols/vyfi/` → [`open-tx3/vyfi-protocols`](https://github.com/open-tx3/vyfi-protocols) — VyFi protocol Tx3 definitions.
- `protocols/snek-fun/` → [`open-tx3/snek-fun-protocols`](https://github.com/open-tx3/snek-fun-protocols) — Snek.fun protocol Tx3 definitions.
- `protocols/acme/` → [`open-tx3/acme-protocols`](https://github.com/open-tx3/acme-protocols) — Acme reference / example protocol definitions.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.
