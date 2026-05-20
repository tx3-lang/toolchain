#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

IMAGE_NAME="${TX3_TEST_RUNNER_IMAGE:-tx3-sdk-test-runner:local}"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"

if ! command -v docker >/dev/null 2>&1; then
  echo "Missing required command: docker"
  exit 1
fi

if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
  echo "Missing Dockerfile: ${DOCKERFILE_PATH}"
  exit 1
fi

echo "Building local e2e runner image: ${IMAGE_NAME}"
docker build -f "${DOCKERFILE_PATH}" -t "${IMAGE_NAME}" "${ROOT_DIR}"

run_args=(
  --rm
  --user "$(id -u):$(id -g)"
  -e HOME=/tmp/tx3-home
  -e CARGO_HOME=/tmp/tx3-home/.cargo
  -v "${ROOT_DIR}:/workspace"
  -w /workspace
)

if [[ -t 1 ]]; then
  run_args+=("-t")
fi

echo "Running transversal e2e suites in container"
docker run "${run_args[@]}" "${IMAGE_NAME}" bash -lc 'mkdir -p "$HOME" && bash scripts/run-e2e-tests.sh "$@"' bash "$@"
