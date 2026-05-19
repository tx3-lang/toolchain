# Testing Strategy

Every Tx3 SDK MUST ship with both **unit tests** and **end-to-end (e2e) tests**. Tests are a first-class deliverable — a capability without a passing test cannot claim a ✅ in the [parity matrix](../../parity-matrix.md).

## Overview

| Layer | Purpose | Runs against | CI gating |
|-------|---------|-------------|-----------|
| [Unit tests](unit-tests.md) | Verify each component in isolation | Mocks / deterministic fixtures | Every PR, every push |
| [End-to-end (e2e) tests](e2e-tests.md) | Verify the full lifecycle end-to-end | A real or local TRP server | Every PR/push in CI; local runs may skip if env is absent |
| [CI workflows](ci-workflows.md) | Define required CI workflow shape and gating semantics | GitHub Actions or equivalent CI system | Unified workflow with required unit + e2e jobs |

## Principles

1. **Tests document behavior.** A test is the most trustworthy form of documentation — it proves the SDK actually does what the spec says. Prefer descriptive test names that read like requirements (e.g., `test_unknown_party_fails_with_clear_error`).
2. **Deterministic by default.** Unit tests MUST NOT depend on network, filesystem timing, or randomness. Use fixed seeds, mocked HTTP, and in-memory fixtures.
3. **Fixtures are shared.** The canonical e2e vector lives in `sdk-spec/test-vectors/transfer/` (including `transfer.tii`). Every SDK MUST use that vector for its happy-path e2e test, and MAY copy or symlink it into `tests/fixtures/` or `examples/`.
4. **Failure paths matter as much as happy paths.** For every capability in the [API surface](../api-surface/), test both the success case and the expected error case.
5. **Semantics are standardized, layout is idiomatic.** Unit tests MUST be deterministic/non-networked and end-to-end (e2e) tests MUST exercise live TRP flow, but file placement MAY follow language norms (for example, Rust/Go co-located unit tests, Python `tests/`, JS/TS co-located or `tests/`).
