#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${ROOT_DIR}/.env"
if [[ "${1:-}" == "-e" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Usage: $0 [-e /path/to/.env]"
    exit 1
  fi
  ENV_FILE="$2"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Create it with e2e credentials before running this script."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

required_env_vars=(
  TRP_ENDPOINT_PREPROD
  TRP_API_KEY_PREPROD
  TEST_PARTY_A_ADDRESS
  TEST_PARTY_A_MNEMONIC
  TEST_PARTY_B_ADDRESS
  TEST_PARTY_B_MNEMONIC
)

missing_vars=()
for var_name in "${required_env_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    missing_vars+=("${var_name}")
  fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
  echo "Missing required environment variables in ${ENV_FILE}:"
  for var_name in "${missing_vars[@]}"; do
    echo "- ${var_name}"
  done
  exit 1
fi

PYTHON_BIN=""
for candidate in python3.13 python3.12 python3.11 python3.10 python python3; do
  if command -v "${candidate}" >/dev/null 2>&1; then
    if "${candidate}" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
      PYTHON_BIN="${candidate}"
      break
    fi
  fi
done

required_bins=(go npm cargo)
for bin in "${required_bins[@]}"; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "Missing required command: ${bin}"
    exit 1
  fi
done

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "Missing supported Python interpreter (>=3.10)."
  echo "Python SDK e2e tests require Python 3.10+ (see python-sdk/sdks/pyproject.toml)."
  exit 1
fi

suite_names=()
suite_results=()
suite_details=()
suite_outputs=()

run_suite() {
  local name="$1"
  local dir="$2"
  shift 2

  local output=""
  local status=0
  local result=""
  local detail=""
  local command_text=""
  local line=""
  local key_line=""
  local last_nonempty=""

  command_text="$(printf '%q ' "$@")"
  command_text="${command_text% }"

  echo
  echo "==> ${name}"
  if output="$( (cd "${dir}" && "$@") 2>&1 )"; then
    result="✅ Pass"
    detail="${command_text}"
    echo "PASS"
  else
    status=$?
    result="❌ Fail"
    while IFS= read -r line; do
      if [[ -n "${line}" ]]; then
        last_nonempty="${line}"
      fi
      if [[ -z "${key_line}" && (
        "${line}" == *"FAILED:"* ||
        "${line}" == *"FAIL:"* ||
        "${line}" == *"error:"* ||
        "${line}" == *"Error:"* ||
        "${line}" == *"panicked at"* ||
        "${line}" == *"No module named"* ||
        "${line}" == *"Submit failed"*
      ) ]]; then
        key_line="${line}"
      fi
    done <<< "${output}"

    if [[ -z "${key_line}" ]]; then
      key_line="${last_nonempty}"
    fi
    key_line="${key_line//|/\\|}"
    detail="${command_text} — ${key_line}"
    echo "FAIL"
  fi

  suite_names+=("${name}")
  suite_results+=("${result}")
  suite_details+=("${detail}")
  suite_outputs+=("${output}")

  return "${status}"
}

overall_status=0

echo "Using env file: ${ENV_FILE}"
echo "Running e2e tests across all SDKs..."

run_suite "Go SDK" "${ROOT_DIR}/go-sdk/sdk" go test -tags=e2e ./e2e -count=1 || overall_status=1
run_suite "Python SDK" "${ROOT_DIR}/python-sdk/sdk" bash -lc "PY_VENV=\"\$(mktemp -d)\" && ${PYTHON_BIN} -m venv \"\${PY_VENV}\" && . \"\${PY_VENV}/bin/activate\" && python -m pip install --upgrade pip && python -m pip install -e '.[dev]' && python -m pytest tests/e2e -m e2e" || overall_status=1
run_suite "Web SDK" "${ROOT_DIR}/web-sdk/sdk" npm run test:e2e || overall_status=1
run_suite "Rust SDK" "${ROOT_DIR}/rust-sdk/sdk" cargo test --test happy_path --test error_cases || overall_status=1

echo
echo "| SDK | Result | Details |"
echo "|-----|--------|---------|"
for i in "${!suite_names[@]}"; do
  echo "| ${suite_names[$i]} | ${suite_results[$i]} | ${suite_details[$i]} |"
done

if [[ "${overall_status}" -ne 0 ]]; then
  echo
  echo "Failed suite outputs:"
  for i in "${!suite_names[@]}"; do
    if [[ "${suite_results[$i]}" == "❌ Fail" ]]; then
      echo
      echo "--- ${suite_names[$i]} ---"
      echo "${suite_outputs[$i]}"
    fi
  done
  exit 1
fi

echo
echo "All e2e suites passed."
