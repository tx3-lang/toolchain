#!/usr/bin/env bash
#
# Journey 01 — basic init.
#
# The canonical "zero to a working transaction" journey on the default scaffold,
# fully offline (no secrets, no live network): scaffold a project, validate it,
# build it, and run
# a real devnet round-trip. The `trix test` step is the integration centerpiece
# — it spins a local Dolos devnet, restores deterministic cshell wallets, submits
# the scaffolded transfer transactions, and asserts the resulting balances —
# exercising trix + tx3c + dolos + cshell + the resolver together.
#
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

journey_begin "01-basic-init" "init → check → build → test (offline devnet round-trip)"

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

# 4. Devnet round-trip. The scaffolded transfers must resolve and submit, and
# the final balances must match. The submit half works; the balance-assertion
# half is a *known, tracked toolchain bug*: `trix test`'s expect phase calls
# `cshell wallet utxos "@bob"` with the literal placeholder instead of the
# wallet name `bob` (the transaction path strips the `@`, the expect path in
# trix's commands/expect.rs does not), so cshell errors with the signature
# below. Reproduces on both stable (trix 0.25.1) and beta (0.26.0). Until trix
# strips the `@`, this step is an xfail — it auto-promotes to a hard failure the
# moment the bug is fixed (see xfail_cmd). The submit half is still asserted
# strictly, so a regression there is caught regardless.
xfail_cmd "trix test — devnet round-trip" "CShell failed to get wallet utxos" \
  "${TRIX}" test tests/basic.toml
assert_output_contains "Dolos daemon started" "devnet came up"
assert_output_contains "bob sends 2 ada to alice" "transfer #1 was driven"
assert_output_contains "alice sends 2 ada to bob" "transfer #2 was driven"

journey_end
