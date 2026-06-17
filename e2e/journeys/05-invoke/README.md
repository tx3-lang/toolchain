# 05-invoke

Covers `trix invoke` — the command a consumer uses to bind CLI arguments to a transaction and
resolve it against a TRP endpoint. A single flow: scaffold a project, bring up a local devnet, and
invoke one transaction, asserting it resolves to an unsigned tx. The fixture's `transfer` tx takes a
deliberately diverse argument set so the one invoke covers the breadth of the CLI arg surface.

- **Scope:** runtime (needs a working devnet — Dolos + the TRP at `:8164`). No secrets, no live
  network beyond the one-time install.
- **Fixture:** `main.tx3`.
- **Channels:** runs everywhere (no `tx3c` floor).

## Resolve-only (`--skip-submit`)

`trix invoke` always resolves against the TRP and hands cshell an empty signer set, so in a non-TTY
(CI) signing is skipped — a full signed submit isn't reachable headlessly. The headless contract is
resolve-only: it prints the unsigned `{ hash, cbor }`. Submission and balances are covered by
`04-devnet-roundtrip`. The fixture is a single tx on purpose: invoke auto-selects the sole
transaction instead of prompting (which would hang in CI).
