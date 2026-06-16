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

# 2. Devnet round-trip: the scaffolded transfers must resolve, submit, and the
# final balances must match — asserted strictly, so the journey fails unless
# `trix test` prints "Test Passed".
#
# NOTE: this currently FAILS on released channels because of a known, tracked
# toolchain bug — trix test's expect phase called `cshell wallet utxos "@bob"`
# with the literal placeholder instead of the wallet name `bob`. Fixed on trix
# main (tx3-lang/trix#123); the journey goes green once that fix ships in a
# channel. Until then the beta e2e job is red here — intentionally, so the broken
# round-trip is a real failure rather than a tolerated xfail.
run_cmd "trix test — devnet round-trip" "${TRIX}" test tests/basic.toml
assert_output_contains "Dolos daemon started" "devnet came up"
assert_output_contains "bob sends 2 ada to alice" "transfer #1 was driven"
assert_output_contains "alice sends 2 ada to bob" "transfer #2 was driven"
assert_output_contains "Test Passed" "balances asserted — round-trip green"

journey_end
