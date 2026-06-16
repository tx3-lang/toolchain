#!/usr/bin/env bash
#
# Journey 04 — devnet round-trip. See README.md for what this covers (and why
# it currently fails on released channels).
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

journey_begin "04-devnet-roundtrip" "init → test (real devnet round-trip)"

# 1. Scaffold a fresh project. `trix test` compiles the TII itself, so no
# separate build step is needed here (01-basic-init covers check/build).
run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
assert_exists "tests/basic.toml" "test scenario scaffolded"

# 2. Devnet round-trip: the scaffolded transfers must resolve, submit, and the
# final balances must match — asserted strictly (must print "Test Passed").
# This currently fails on released channels (known trix bug; see README.md).
run_cmd "trix test — devnet round-trip" "${TRIX}" test tests/basic.toml
assert_output_contains "Dolos daemon started" "devnet came up"
assert_output_contains "bob sends 2 ada to alice" "transfer #1 was driven"
assert_output_contains "alice sends 2 ada to bob" "transfer #2 was driven"
assert_output_contains "Test Passed" "balances asserted — round-trip green"

journey_end
