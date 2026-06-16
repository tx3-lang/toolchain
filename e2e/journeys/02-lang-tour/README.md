# 02-lang-tour

Coverage journey: swap the default scaffold's `main.tx3` for a deliberately feature-dense protocol
(`main.tx3` here, a copy of the lang's `lang_tour` example) and push it through the full compile +
lower pipeline (`check → build → inspect tir`). Exercises the breadth of the language surface — env
block, records, variants, lists/maps/tuples, policies & assets, record spread, locals, and the whole
Cardano construct set (mint/burn, collateral, reference, withdrawal, certificates, plutus/native
witnesses, treasury donation, metadata, validity).

- **Scope:** compile/lower only — the tx references hard-coded UTxOs, mints, and plutus scripts, so it
  can't resolve against a fresh devnet (the round-trip lives in `04-devnet-roundtrip`).
- **Fixture:** `main.tx3`.
- **Capability:** tuples need `tx3c >= 0.22` (`#@ min-tx3c: 0.22.0`), so it's skipped on older channels.
