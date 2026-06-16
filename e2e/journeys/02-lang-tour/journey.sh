#!/usr/bin/env bash
#
# Journey 02 — language tour. See README.md for what this covers.
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.
#
#@ min-tx3c: 0.22.0

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

JOURNEY_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

journey_begin "02-lang-tour" "init → swap in feature-dense main.tx3 → check → build → inspect tir"

# 1. Scaffold, then replace the trivial transfer with the feature-dense protocol.
run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
cp "${JOURNEY_HOME}/main.tx3" main.tx3
assert_exists "main.tx3" "feature-dense main.tx3 in place"

# 2. Analyze the full language surface through tx3c.
run_cmd "trix check — analyze the feature-dense protocol" "${TRIX}" check
assert_output_contains "check passed"

# 3. Compile to TII — proves every construct lowers to the interface.
run_cmd "trix build — compile feature-dense protocol to TII" "${TRIX}" build
assert_found "TII artifact produced under .tx3/tii" ".tx3/tii" "main.tii"

# 4. Lower a single tx to TIR and confirm the Cardano + type-system constructs
# actually made it through — not just that the build exited 0.
run_cmd "trix inspect tir --tx my_tx — lower to TIR" "${TRIX}" inspect tir --tx my_tx
assert_output_contains "treasury_donation"           "treasury donation lowered"
assert_output_contains "plutus_witness"              "plutus witness lowered"
assert_output_contains "native_witness"              "native witness lowered"
assert_output_contains "vote_delegation_certificate" "certificate lowered"
assert_output_contains "withdrawal"                  "withdrawal lowered"
assert_output_contains "Map"                         "map type lowered"
assert_output_contains "Tuple"                        "tuple type lowered"

journey_end
