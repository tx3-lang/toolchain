# CI Workflow Policy

Every Tx3 SDK MUST define CI behavior through a single unified workflow that enforces test quality consistently across languages.

This policy is normative. Keywords **MUST**, **SHOULD**, and **MAY** are interpreted as described in `sdk-spec/README.md`.

---

## Unified workflow requirement

Each SDK repository MUST include one CI workflow category that runs on:

- `pull_request` targeting the default branch
- `push` to the default branch

The workflow MAY contain multiple jobs, but the required baseline jobs are:

- `unit` (or language-idiomatic equivalent) for unit-level checks
- `e2e` (or language-idiomatic equivalent) for end-to-end checks

Job names MAY vary by language conventions, but both required job intents MUST be present.

---

## Required job behavior

### Unit job (MUST)

- MUST run on every configured trigger.
- MUST fail the workflow if unit tests fail.
- MUST execute deterministic, non-network-dependent tests as defined in [unit-tests.md](unit-tests.md).

### End-to-end (e2e) job (MUST)

- MUST be present in the unified workflow.
- MUST run on every configured trigger.
- MUST fail fast when required e2e environment variables or secrets are missing in CI.
- MUST map e2e environment variables from CI secrets using the canonical names defined in [e2e-tests.md](e2e-tests.md).
- MUST fail when e2e tests fail.
- Local developer test commands MAY still use skip-if-absent behavior as defined in [e2e-tests.md](e2e-tests.md).

---

## Trigger and branch policy

- The unified workflow MUST be active for all pull requests against the default branch.
- The unified workflow MUST be active for pushes to the default branch.
- Additional triggers (schedule, manual dispatch, release) MAY be added, but they do not replace required PR/push triggers.

---

## Visibility and diagnostics

- The workflow MUST expose unit and e2e outcomes as separate job results.
- If e2e configuration is missing, logs MUST show a clear fail-fast reason (for example, missing `TRP_ENDPOINT_PREPROD`).
- Logs MUST make it clear that e2e checks were executed under CI.

---

## Recommended hardening (SHOULD)

- Use dependency/module caching to reduce CI latency.
- Pin toolchain/runtime versions (Rust toolchain, Node, Go, Python).
- Use concurrency controls to cancel superseded in-progress runs for the same branch.
- Set explicit per-job timeouts to avoid hung runners.

---

## Language-specific command examples

These are examples only. SDKs MUST preserve behavior, but command shape may follow language idioms.

- Rust unit: `cargo test --lib`
- Rust e2e: `cargo test --test happy_path --test error_cases` (plus other e2e targets as needed)
- Web unit: `npm run test:unit` (or equivalent package script)
- Web e2e: `npm run test:e2e`
- Go unit: `go test ./...`
- Go e2e: `go test -tags=e2e ./...` (or package-specific equivalent)
- Python unit: `pytest -m "not e2e"`
- Python e2e: `pytest -m e2e`

If an SDK uses a different test selection mechanism, it MUST still preserve the same unit/e2e gating semantics.
