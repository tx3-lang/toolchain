# 06-hydra

A self-contained Hydra runtime journey: bring up a local Hydra node (offline
mode) and tx3-hydra, compile a minimal Tx3 transfer, and resolve it through the
tx3-hydra TRP.

- **Scope:** runtime. Requires Docker with Compose support; skips green when
  Docker is unavailable or the host is not amd64 (the hydra-node image is
  linux/amd64 only and too slow under QEMU emulation on arm64).
- **Self-contained:** the `docker-compose.yml`, chain fixtures (`utxo.json`,
  hydra keys, protocol parameters), tx3-hydra config, and a minimal `main.tx3`
  transfer fixture all live in this journey folder. The only external
  dependency is the tx3-hydra source (built from the `backends/tx3-hydra`
  submodule via the compose `build` context).
- **Resolve path:** uses `trix build` + a direct `curl` to `trp.resolve` (not
  `trix invoke`), so the journey exercises only the TRP at `:8164` and does not
  depend on cshell or a U5C endpoint.

## Regression Coverage

Hydra 2.x heads open directly and empty (ADR-33); the L2 ledger is seeded by
`--initial-utxo` in offline mode. This journey checks that:

- tx3-hydra parses the 2.x `HeadIsOpen` event (no `utxo` field) — asserted via
  the `"Head is open"` log line.
- tx3-hydra parses `Greetings` and tracks the seeded UTxO set — asserted
  indirectly by a successful `trp.resolve` (resolve fails if the UTxO set is
  empty).
