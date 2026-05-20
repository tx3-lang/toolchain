# Unit Test Strategy

Unit tests verify each component in isolation. They MUST run without network access, without a TRP server, and without environment variables.

Unit test files MAY be co-located with implementation modules (idiomatic in Rust/Go and common in TS/JS) or centralized under a `tests/` package (idiomatic in Python). Layout is language-specific; semantics are not.

---

## Per-component requirements

### TII (Protocol Loading)

- Parse a valid `.tii` fixture and assert the `Protocol` exposes the expected transactions, parties, and param types.
- Reject malformed JSON (missing required fields, invalid structure) with a TII-specific error.
- Reject unknown `ParamType` values gracefully (don't panic or throw an untyped error).
- Verify that `fromFile` and `fromString`/`fromBytes` produce equivalent `Protocol` objects for the same input.

### TRP (Low-Level Client)

- Mock HTTP responses for `resolve`, `submit`, and `checkStatus`.
- Verify the request shape matches the TRP JSON-RPC spec (method name, params structure, headers).
- Verify error responses (HTTP 4xx/5xx, JSON-RPC error objects) produce the correct TRP-specific error type.
- Test header injection via `ClientOptions`.

### Signers

- `Ed25519Signer`: construct from a known private key, sign a known hash, verify the signature and public key match expected values. This MUST be a deterministic round-trip test with hardcoded inputs/outputs.
- `CardanoSigner`: construct from a known mnemonic, verify the derived address matches the expected address for the `m/1852'/1815'/0'/0/0` path.
- Custom `Signer`: implement a trivial mock signer conforming to the interface and verify it integrates with the facade's `sign()` step.
- Verify `Witness` structure: public key, signature, and witness type are all present and correctly formatted.

### Facade

- Builder validation: calling `.tx("nonexistent")` on a `Tx3Client` MUST fail with an appropriate error.
- Party injection: attach a party via `withParty`, build an invocation, and verify the party's address appears in the args map under the party's name.
- Unknown party: attaching a party name not declared in the `Protocol` MUST produce an `UnknownParty` error at `resolve()` time.
- State machine: verify the chain `ResolvedTx -> SignedTx -> SubmittedTx` enforces ordering (e.g., you can't call `submit()` on a `ResolvedTx`).

### Argument Marshalling

- Native integers, strings, booleans, and byte arrays round-trip through the marshaller to the expected TRP wire format.
- Argument key matching is case-insensitive.
- Unknown argument names (not declared in the protocol's params) produce a clear error.
- `ArgValue` tagged values (e.g., `UtxoRef`, `UtxoSet`) serialize correctly.

### Error Model

- Each error category from [&sect;3.8](../api-surface/errors.md) is discriminable without string matching.
- Error messages include enough context to debug (param name, party name, HTTP status, etc.).

---

## Coverage expectations

- Every **public function or method** MUST have at least one unit test.
- Every **error path** documented in the [API surface](../api-surface/) MUST have a corresponding test.
- Coverage tools are encouraged but not mandated. The bar is behavioral coverage (every documented behavior is tested), not line-count coverage.

---

## Test naming convention

Use descriptive names that read like requirements. The host language's convention applies for formatting, but the intent should be clear:

- Rust: `#[test] fn unknown_party_returns_error()`
- TypeScript: `it("returns UnknownParty error when party is not in protocol")`
- Python: `def test_unknown_party_returns_error():`
