#!/usr/bin/env bash
#
# Journey 06 - Hydra. See README.md for what this covers.
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.

source "${E2E_LIB:?E2E_LIB not set - run this journey via e2e/run.sh}"

JOURNEY_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${JOURNEY_HOME}/../../.." && pwd)"
COMPOSE_FILE="${JOURNEY_HOME}/docker-compose.yml"
COMPOSE_PROJECT="tx3hydra${RANDOM}${RANDOM}"

# Address seeded by chain/utxo.json (100 ADA) and a receiver address.
SENDER="addr_test1vz5yzy8fttld8yprtzhsz5kuwk46xs9npnfdh3ajaggm5ccyg00d6"
RECEIVER="addr_test1vpg24ht6y8p6500k56hh9q0994rdvn2xulnul7a6w0yx4mg68vswg"

compose() {
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" "$@"
}

cleanup() {
  if command -v docker >/dev/null 2>&1; then
    compose down -v --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    skip "docker not found - skipping Hydra runtime journey"
    journey_end
    exit 0
  fi

  if ! docker info >/dev/null 2>&1; then
    skip "docker daemon unavailable - skipping Hydra runtime journey"
    journey_end
    exit 0
  fi

  if ! docker compose version >/dev/null 2>&1; then
    skip "docker compose unavailable - skipping Hydra runtime journey"
    journey_end
    exit 0
  fi

  # The hydra-node image is linux/amd64 only; under QEMU emulation on arm64
  # the Haskell binary is too slow to start within the journey timeout.
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "x86_64" ]]; then
    skip "hydra-node image is amd64-only - skipping on ${arch}"
    journey_end
    exit 0
  fi
}

wait_for_http() {
  local url="$1" label="$2" attempts="${3:-90}"

  for _ in $(seq 1 "${attempts}"); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      ok "${label} reachable"
      return 0
    fi
    sleep 2
  done

  die "timed out waiting for ${label}: ${url}"
}

wait_for_rpc_health() {
  local url="$1" label="$2" attempts="${3:-90}"

  for _ in $(seq 1 "${attempts}"); do
    local resp
    resp="$(curl -fsS -X POST "${url}" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"health","id":1}' 2>/dev/null || true)"
    if echo "${resp}" | grep -q '"result":true'; then
      ok "${label}"
      return 0
    fi
    sleep 2
  done

  die "timed out waiting for ${label}"
}

wait_for_logs() {
  local service="$1" needle="$2" label="$3" attempts="${4:-90}"

  for _ in $(seq 1 "${attempts}"); do
    if compose logs --no-color "${service}" 2>/dev/null | grep -qiF -- "${needle}"; then
      ok "${label}"
      return 0
    fi
    sleep 2
  done

  compose logs --no-color "${service}" || true
  die "timed out waiting for ${label}"
}

assert_logs_do_not_contain() {
  local service="$1" needle="$2" label="$3"

  if compose logs --no-color "${service}" | grep -qiF -- "${needle}"; then
    compose logs --no-color "${service}" || true
    die "unexpected log entry for ${label}: ${needle}"
  fi

  ok "${label}"
}

journey_begin "06-hydra" "Hydra runtime: start stack -> resolve a Tx3 transfer through TRP"

require_docker

assert_exists "${COMPOSE_FILE}" "self-contained compose fixture exists"
assert_exists "${JOURNEY_HOME}/utxo.json" "initial UTxO fixture exists"

# 1. Bring up a self-contained Hydra stack: hydra-node (offline, seeded UTxO)
#    + tx3-hydra (pre-built image from GHCR). No build step, no submodule.
run_cmd "docker compose up - start Hydra stack" compose up -d hydra-node hydra-tx3

wait_for_http "http://127.0.0.1:4001/protocol-parameters" "hydra-node API"
wait_for_rpc_health "http://127.0.0.1:8164" "tx3-hydra health"
# In Hydra 2.x the head opens directly at startup, so HeadIsOpen fires before
# tx3-hydra subscribes. The UTxO set arrives via Greetings + SnapshotConfirmed
# (offline --initial-utxo enters through the deposit mechanism). Wait for the
# snapshot to prove the head UTxO set is tracked before resolving.
wait_for_logs "hydra-tx3" "Snapshot updated" "head UTxO set tracked"

# 2. Compile a minimal transfer fixture and extract the TIR bytecode. Using
#    trix build + curl (instead of trix invoke) keeps the journey independent
#    of cshell/U5C - only the TRP at :8164 is exercised.
run_cmd "trix init -y - scaffold a project" "${TRIX}" init -y
cp "${JOURNEY_HOME}/main.tx3" main.tx3
run_cmd "trix check - analyze the fixture" "${TRIX}" check
assert_output_contains "check passed"
run_cmd "trix build - compile to TII" "${TRIX}" build

TII_FILE="$(find .tx3/tii -name main.tii | head -n1)"
[[ -n "${TII_FILE}" ]] || die "no main.tii produced by trix build"
ok "TII artifact found: ${TII_FILE}"

BYTECODE="$(python3 -c "import json; print(json.load(open('${TII_FILE}'))['transactions']['transfer']['tir']['content'])")"
TIR_VERSION="$(python3 -c "import json; print(json.load(open('${TII_FILE}'))['transactions']['transfer']['tir']['version'])")"
[[ -n "${BYTECODE}" && -n "${TIR_VERSION}" ]] || die "could not extract TIR bytecode from TII"
ok "extracted TIR bytecode (${#BYTECODE} hex chars, ${TIR_VERSION})"

# 3. Resolve the transfer against the tx3-hydra TRP. The sender is the address
#    seeded by the offline head's --initial-utxo; resolve succeeds only if
#    tx3-hydra parsed Greetings and tracked the head UTxO set.
run_cmd "trp.resolve - resolve the transfer through tx3-hydra" \
  curl -fsS -X POST "http://127.0.0.1:8164" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"trp.resolve\",\"params\":{\"tir\":{\"bytecode\":\"${BYTECODE}\",\"encoding\":\"hex\",\"version\":\"${TIR_VERSION}\"},\"args\":{\"sender\":\"${SENDER}\",\"receiver\":\"${RECEIVER}\",\"quantity\":1000000}},\"id\":1}"
assert_output_contains '"tx"' "resolve returned a transaction"

journey_end
