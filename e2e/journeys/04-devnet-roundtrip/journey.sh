#!/usr/bin/env bash
#
# Journey 04 — devnet round-trip.
#
# The integration centerpiece, split out of 01-basic-init so the basic gate
# stays fast and offline. Scaffolds the default project and runs a real
# `trix test`: it spins a local Dolos devnet, restores deterministic cshell
# wallets, submits the scaffolded transfers, and asserts the resulting balances
# — exercising trix + tx3c + dolos + cshell + the resolver together.
#
# Scope is runtime (needs a working devnet); no secrets, no live network beyond
# the one-time install. Scheduled on the beta e2e job only for now — see
# .github/workflows/dx-e2e.yml.
#
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

journey_begin "04-devnet-roundtrip" "init → test (real devnet round-trip)"

# 1. Scaffold a fresh project. `trix test` compiles the TII itself, so no
# separate build step is needed here (01-basic-init covers check/build).
run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
assert_exists "tests/basic.toml" "test scenario scaffolded"

# 2. Devnet round-trip. The scaffolded transfers must resolve and submit, and
# the final balances must match. The submit half works; the balance-assertion
# half is a *known, tracked toolchain bug*: trix test's expect phase called
# `cshell wallet utxos "@bob"` with the literal placeholder instead of the
# wallet name `bob`, so cshell errors with the signature below. Fixed on trix
# main (tx3-lang/trix#123) but not yet in a released channel; until a channel
# ships it this stays an xfail and auto-promotes to a hard failure the moment it
# starts passing (see xfail_cmd). The submit half is asserted strictly regardless.
xfail_cmd "trix test — devnet round-trip" "CShell failed to get wallet utxos" \
  "${TRIX}" test tests/basic.toml
assert_output_contains "Dolos daemon started" "devnet came up"
assert_output_contains "bob sends 2 ada to alice" "transfer #1 was driven"
assert_output_contains "alice sends 2 ada to bob" "transfer #2 was driven"

journey_end
