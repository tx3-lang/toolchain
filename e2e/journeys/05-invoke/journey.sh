#!/usr/bin/env bash
#
# Journey 05 — trix invoke. See README.md for what this covers.
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.
#
#@ min-tx3c: 0.23.0

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

JOURNEY_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

journey_begin "05-invoke" "init → devnet → invoke a transaction and resolve it"

# 1. Scaffold (gives the implicit `local` profile and a devnet.toml that funds
#    alice/bob/charlie), then swap in the invoke fixture — a single tx so invoke
#    auto-selects it without an interactive prompt.
run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
cp "${JOURNEY_HOME}/main.tx3" main.tx3
run_cmd "trix check — analyze the fixture" "${TRIX}" check
assert_output_contains "check passed"

# 2. Resolve the deterministic party addresses (parties bind as Address args).
ALICE="$("${TRIX}" identities alice address-testnet 2>/dev/null | grep '^addr' | head -n1)"
BOB="$("${TRIX}" identities bob address-testnet 2>/dev/null | grep '^addr' | head -n1)"
[[ -n "${ALICE}" && -n "${BOB}" ]] || die "could not resolve alice/bob testnet addresses"

# 3. Bring up a local devnet (Dolos + TRP at :8164) — invoke resolves against it.
#    Record the dolos PIDs we spawn and trap-kill only those, so an aborted
#    assertion never leaves a daemon behind.
run_cmd "trix devnet --background — start a local devnet" "${TRIX}" devnet --background
assert_output_contains "devnet started in background"
DEVNET_PIDS="$(pgrep -f 'dolos.*daemon' | tr '\n' ' ')"
# shellcheck disable=SC2064
trap "[[ -n \"${DEVNET_PIDS}\" ]] && kill -9 ${DEVNET_PIDS} 2>/dev/null" EXIT
for _ in $(seq 1 30); do
  (exec 3<>/dev/tcp/127.0.0.1/8164) 2>/dev/null && { exec 3>&- 3<&-; break; }
  sleep 1
done
sleep 3

# 4. Invoke the transaction with the fixture's full argument set and require it
#    to resolve to an unsigned tx. --skip-submit keeps it headless: invoke never
#    signs without a TTY (see README), so resolve-only is the mode.
run_cmd "trix invoke — resolve the transaction" \
  "${TRIX}" invoke --skip-submit \
  --args-json "{\"sender\":\"${ALICE}\",\"receiver\":\"${BOB}\",\"quantity\":2000000,\"urgent\":true,\"memo\":\"deadbeef\",\"meta\":{\"tags\":[1,2,3],\"level\":7}}"
assert_output_contains '"cbor"' "invoke resolved to an unsigned transaction"
assert_output_contains '"hash"' "resolved tx carries a hash"

journey_end
