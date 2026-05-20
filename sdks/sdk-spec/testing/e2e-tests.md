# End-to-End (e2e) Test Strategy

End-to-end (e2e) tests verify the full transaction lifecycle against a real or local TRP server. They are the ultimate proof that an SDK works.

---

## Happy-path test

Every SDK MUST have at least one e2e test that exercises the complete chain:

```
load protocol -> configure client -> attach parties -> build tx -> resolve -> sign -> submit -> waitForConfirmed
```

This test MUST use the canonical `transfer` vector in `sdk-spec/test-vectors/transfer/` (specifically `transfer.tii`), real signers (from a test mnemonic), and a real TRP endpoint.

---

## Environment variables

End-to-end (e2e) tests are configured via environment variables. This convention is shared across all SDKs:

| Variable | CI required | Description |
|----------|-------------|-------------|
| `TRP_ENDPOINT_PREPROD` | Yes | Full URL of the preprod TRP server (e.g., `https://preprod.trp.tx3.dev`) |
| `TRP_API_KEY_PREPROD` | Yes | API key for the preprod TRP server |
| `TEST_PARTY_A_ADDRESS` | Yes | Bech32 address for the first test party |
| `TEST_PARTY_A_MNEMONIC` | Yes | BIP39 mnemonic for the first test party's signer |
| `TEST_PARTY_B_ADDRESS` | Yes | Address for a second party (for multi-party tests) |
| `TEST_PARTY_B_MNEMONIC` | Yes | Mnemonic for the second party |

In CI, all six variables above MUST be provided via CI secrets and wired into the e2e job environment.

For local developer runs (`cargo test` / `npm test` / `pytest`), e2e tests MAY still be skipped when configuration is absent so day-to-day workflows run cleanly without TRP access.

SDKs MUST provide an explicit e2e-test selector (for example: Go build tags, Python pytest markers, dedicated JS/TS npm script, or Rust test target list) so CI can run unit and e2e suites independently regardless of folder layout.

---

## Fixture strategy

- The canonical e2e test vector lives at `sdk-spec/test-vectors/transfer/` and includes `transfer.tx3`, `transfer.tii`, and `transfer.preprod.env`.
- SDK e2e tests MUST use `sdk-spec/test-vectors/transfer/transfer.tii` for the happy-path lifecycle test.
- SDKs MAY copy or symlink canonical vectors into local `tests/fixtures/` or `examples/` paths for language-idiomatic test layout.
- Do NOT generate `.tii` files at test time. The Tx3 compiler is out of scope for SDKs.
- If a test needs a new shared fixture, add it under `sdk-spec/test-vectors/` first so all SDKs can consume the same canonical vector.

---

## Error-case e2e tests

Beyond the happy path, SDKs SHOULD test:

- **Bad endpoint**: point the TRP client at a non-existent host and verify a transport error is returned (not a panic or unhandled rejection).
- **Invalid protocol**: attempt to resolve a transaction with missing required args and verify a resolution error.
- **Poll timeout**: submit a transaction and poll with `PollConfig { attempts: 1, delay: 0 }` — verify the timeout error path works.

---

## CI gating

- **Unit tests**: run on every PR and every push. No exceptions.
- **End-to-end (e2e) tests**: run on every PR and every push in CI.
- **CI configuration**: required e2e env vars/secrets MUST be present in CI; if missing, the e2e job MUST fail fast with an explicit error.
- **Local workflows**: skip-if-absent behavior remains acceptable for local development commands.
- SDKs SHOULD document how to run e2e tests locally in their `README.md` (which env vars to set, where to get test credentials).
