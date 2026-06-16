#!/usr/bin/env bash
#
# Journey 01 — basic init. See README.md for what this covers.
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

journey_begin "01-basic-init" "init → check → build (offline scaffold validation)"

# 1. Scaffold a fresh project and confirm the expected files land.
run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
assert_exists "trix.toml"        "trix.toml created"
assert_exists "main.tx3"         "main.tx3 created"
assert_exists "tests/basic.toml" "tests/basic.toml created"
assert_exists ".gitignore"       ".gitignore created"
assert_exists "devnet.toml"      "devnet.toml created"

# 2. Parse + analyze the protocol through the real tx3c binary.
run_cmd "trix check — parse + analyze" "${TRIX}" check
assert_output_contains "check passed"

# 3. Compile to the Transaction Invocation Interface (TII).
run_cmd "trix build — compile to TII" "${TRIX}" build
assert_found "TII artifact produced under .tx3/tii" ".tx3/tii" "main.tii"

journey_end
