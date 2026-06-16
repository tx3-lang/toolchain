#!/usr/bin/env bash
#
# Journey 03 — language edge.
#
# Coverage journey focused on the *newest* language-level additions, the
# complement to 02-lang-tour's broad surface: user-defined functions (`fn` with
# `let`), the `*` and `/` operators, parametric tuples (`Tuple<…>` types,
# literals, and indexing), and `///` doc-comments. Swaps in this directory's
# feature-dense main.tx3 and pushes it through compile + lower.
#
# Scope is compile/lower only (no devnet round-trip). These features need
# tx3c >= 0.22, so the journey is skipped on older channels (e.g. stable's 0.21).
#
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.
#
#@ min-tx3c: 0.22.0

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

JOURNEY_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

journey_begin "03-lang-edge" "init → swap in edge-feature main.tx3 → check → build → inspect tir"

# 1. Scaffold, then replace the trivial transfer with the edge-feature protocol.
run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
cp "${JOURNEY_HOME}/main.tx3" main.tx3
assert_exists "main.tx3" "edge-feature main.tx3 in place"

# 2. Analyze the newest constructs through tx3c.
run_cmd "trix check — analyze the edge-feature protocol" "${TRIX}" check
assert_output_contains "check passed"

# 3. Compile to TII — proves every construct lowers to the interface.
run_cmd "trix build — compile edge-feature protocol to TII" "${TRIX}" build
assert_found "TII artifact produced under .tx3/tii" ".tx3/tii" "main.tii"

# 4. Lower `settle` and confirm functions + operators + tuple literals made it
# through: the `*`/`/` from the inlined fns become Mul/Div eval nodes.
run_cmd "trix inspect tir --tx settle — lower to TIR" "${TRIX}" inspect tir --tx settle
assert_output_contains '"Mul"'   "multiply operator lowered"
assert_output_contains '"Div"'   "divide operator lowered"
assert_output_contains '"Tuple"' "tuple literal lowered"

# 5. Lower `redeem` and confirm tuple *indexing* lowered (element access becomes
# a Property node over the tuple).
run_cmd "trix inspect tir --tx redeem — lower to TIR" "${TRIX}" inspect tir --tx redeem
assert_output_contains '"Property"' "tuple indexing lowered"
assert_output_contains '"Tuple"'    "tuple present in redeem"

journey_end
