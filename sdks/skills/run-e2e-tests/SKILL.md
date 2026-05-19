---
name: run-e2e-tests
description: Run local e2e tests across Rust/Web/Go/Python from lang-factory/sdk using one .env file and the Docker-based shared script.
---

# run-e2e-tests

Run all SDK e2e tests locally from `lang-factory/sdks/` with one shared `.env` file, using Docker so host toolchains are not required.

## When to use

- "Run e2e tests across all SDKs locally."
- "Smoke test parity before opening cross-SDK PRs."
- "Validate TRP credentials work for every SDK."

## Prerequisites

- Docker daemon running locally.
- A `.env` file at `lang-factory/sdks/.env` (or a custom path passed with `-e`).

## Required .env variables

```bash
TRP_ENDPOINT_PREPROD=https://preprod.trp.tx3.dev
TRP_API_KEY_PREPROD=your_api_key
TEST_PARTY_A_ADDRESS=addr_test1...
TEST_PARTY_A_MNEMONIC="word1 word2 ..."
TEST_PARTY_B_ADDRESS=addr_test1...
TEST_PARTY_B_MNEMONIC="word1 word2 ..."
```

## Command

From `lang-factory/sdks/`:

```bash
sdks/scripts/run-e2e-tests-docker.sh
```

This is the default and preferred command. Use the Docker wrapper unless the user explicitly asks for host-toolchain execution.

Use a non-default env file:

```bash
sdks/scripts/run-e2e-tests-docker.sh -e /path/to/.env
```

## Docker workflow

1. Build local test-runner image from `scripts/Dockerfile`.
2. Mount the repository into `/workspace` inside the container.
3. Execute `sdks/scripts/run-e2e-tests.sh` in-container.

## What the script runs

1. Go: `go test -tags=e2e ./e2e -count=1`
2. Python: `python -m pip install -e '.[dev]' && python -m pytest tests/e2e -m e2e`
3. Web: `npm run test:e2e`
4. Rust: `cargo test --test happy_path --test error_cases`

## Failure handling

- Missing `.env`, missing variables, missing Docker, or Docker build/run failures fail fast with a clear message.
- The script runs every SDK suite even when earlier suites fail.
- The script exits non-zero at the end if any suite failed.
- Rerun after fixing the reported issue.

## Guardrails

- Keep this as a local orchestration utility. Do not make it release/deploy automation.
- Keep the runner image local-build only for now; do not introduce registry push/pull flow.
- Do not commit real credentials to `.env`; use local untracked files.
