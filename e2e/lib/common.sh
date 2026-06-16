#!/usr/bin/env bash
# Shared helpers for DX e2e journeys.
#
# A "journey" sources this file and then drives the `trix` CLI with the
# assertion helpers below. Every helper is fail-fast: on a failed assertion it
# prints a clear message and exits non-zero, which `e2e/run.sh` records as a
# failed journey. Journeys therefore read as a linear script with no explicit
# error handling.
#
# Contract from e2e/run.sh (exported into the journey's environment):
#   TRIX         path/name of the trix binary to exercise
#   E2E_VERBOSE  "1" to stream command output, "0" to capture it
#   PWD          the journey's isolated working directory

set -uo pipefail

# --- presentation ----------------------------------------------------------

if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_DIM=$'\033[2m'; _C_RED=$'\033[31m'
  _C_GREEN=$'\033[32m'; _C_YELLOW=$'\033[33m'; _C_BLUE=$'\033[34m'
else
  _C_RESET=""; _C_DIM=""; _C_RED=""; _C_GREEN=""; _C_YELLOW=""; _C_BLUE=""
fi

info() { printf '%s   %s%s\n' "${_C_BLUE}" "$*" "${_C_RESET}"; }
ok()   { printf '%s ✔ %s%s\n' "${_C_GREEN}" "$*" "${_C_RESET}"; }
warn() { printf '%s ! %s%s\n' "${_C_YELLOW}" "$*" "${_C_RESET}"; }
err()  { printf '%s ✗ %s%s\n' "${_C_RED}" "$*" "${_C_RESET}" >&2; }

die() { err "$*"; exit 1; }

# Captured combined output of the most recent `run_cmd`, for assert_output_*.
LAST_OUTPUT_FILE="${LAST_OUTPUT_FILE:-${PWD}/.last_cmd_output}"

# --- journey scaffolding ---------------------------------------------------

journey_begin() {
  local title="$1" desc="${2:-}"
  printf '\n%s== journey: %s ==%s\n' "${_C_DIM}" "${title}" "${_C_RESET}"
  [[ -n "${desc}" ]] && printf '%s   %s%s\n' "${_C_DIM}" "${desc}" "${_C_RESET}"
  return 0
}

journey_end() {
  ok "journey passed"
  return 0
}

# --- command runner --------------------------------------------------------

# run_cmd "<human description>" <cmd> [args...]
# Runs the command, capturing combined output to LAST_OUTPUT_FILE. Streams the
# output live when E2E_VERBOSE=1. Aborts the journey if the command fails.
run_cmd() {
  local desc="$1"; shift
  info "→ ${desc}"
  : > "${LAST_OUTPUT_FILE}"

  local rc
  if [[ "${E2E_VERBOSE:-0}" == "1" ]]; then
    "$@" 2>&1 | tee "${LAST_OUTPUT_FILE}"
    rc=${PIPESTATUS[0]}
  else
    "$@" > "${LAST_OUTPUT_FILE}" 2>&1
    rc=$?
  fi

  if [[ "${rc}" -ne 0 ]]; then
    err "command failed (exit ${rc}): $*"
    printf '%s---- captured output ----%s\n' "${_C_DIM}" "${_C_RESET}" >&2
    cat "${LAST_OUTPUT_FILE}" >&2
    printf '%s-------------------------%s\n' "${_C_DIM}" "${_C_RESET}" >&2
    exit 1
  fi
  ok "${desc}"
}

# xfail_cmd "<label>" "<known-failure-signature>" <cmd> [args...]
# For a step that is *expected to fail* because of a known, tracked upstream bug.
# Captures output to LAST_OUTPUT_FILE, then:
#   - fails the journey if the command FAILS with an *unexpected* signature
#     (i.e. a new/different breakage we want to hear about);
#   - tolerates (and loudly logs) the known failure when the signature matches;
#   - if the command now SUCCEEDS, logs an "xpass" nudge to promote it to a
#     strict assertion — so the xfail auto-surfaces once the bug is fixed.
# Returns 0 in both the known-fail and xpass cases so the journey continues.
xfail_cmd() {
  local label="$1" signature="$2"; shift 2
  info "→ ${label} ${_C_DIM}(xfail: ${signature})${_C_RESET}"
  : > "${LAST_OUTPUT_FILE}"

  local rc
  if [[ "${E2E_VERBOSE:-0}" == "1" ]]; then
    "$@" 2>&1 | tee "${LAST_OUTPUT_FILE}"; rc=${PIPESTATUS[0]}
  else
    "$@" > "${LAST_OUTPUT_FILE}" 2>&1; rc=$?
  fi

  if [[ "${rc}" -eq 0 ]]; then
    warn "XPASS: '${label}' now succeeds — promote this to a strict assertion and drop the xfail"
    return 0
  fi
  if grep -qiF -- "${signature}" "${LAST_OUTPUT_FILE}"; then
    warn "XFAIL (known upstream bug): '${label}' failed with expected signature: ${signature}"
    return 0
  fi
  err "'${label}' failed, but NOT with the known signature '${signature}' (exit ${rc})"
  printf '%s---- captured output ----%s\n' "${_C_DIM}" "${_C_RESET}" >&2
  cat "${LAST_OUTPUT_FILE}" >&2
  printf '%s-------------------------%s\n' "${_C_DIM}" "${_C_RESET}" >&2
  exit 1
}

# --- assertions ------------------------------------------------------------

assert_exists() {
  local path="$1" desc="${2:-file exists: $1}"
  [[ -e "${path}" ]] || die "expected path is missing: ${path}"
  ok "${desc}"
}

# assert_found "<desc>" <dir> <filename> — at least one matching file under dir.
assert_found() {
  local desc="$1" dir="$2" name="$3"
  if [[ -d "${dir}" ]] && find "${dir}" -name "${name}" -type f | grep -q .; then
    ok "${desc}"
  else
    die "expected to find a file named '${name}' under '${dir}'"
  fi
}

# assert_output_contains "<needle>" ["<desc>"] — checks the last run_cmd output.
assert_output_contains() {
  local needle="$1" desc="${2:-output contains \"$1\"}"
  if grep -qiF -- "${needle}" "${LAST_OUTPUT_FILE}"; then
    ok "${desc}"
  else
    err "expected output to contain: ${needle}"
    printf '%s---- captured output ----%s\n' "${_C_DIM}" "${_C_RESET}" >&2
    cat "${LAST_OUTPUT_FILE}" >&2
    printf '%s-------------------------%s\n' "${_C_DIM}" "${_C_RESET}" >&2
    exit 1
  fi
}
