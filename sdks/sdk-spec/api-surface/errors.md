# &sect;3.8 &mdash; Error Model

An SDK MUST expose a single top-level error type (or error hierarchy) that distinguishes at least:

- **TII / protocol errors** — bad TII file, JSON parse failure, schema validation failure (raised by the loaders in [tii.md](tii.md)).
- **Name-lookup errors** — `UnknownTx`, `UnknownProfile`, `UnknownParty`. `UnknownTx` is returned by `tx(name)` on the built client. `UnknownProfile` and `UnknownParty` are returned by `Tx3ClientBuilder.build()` — the optional `withProfile` / `withParty` setters defer name validation to `build()` so chains stay fluent. The optional late-binding `withParty` on the built client returns `UnknownParty` at the call site (see [facade.md §3.3 Name lookups](facade.md#name-lookups-must)).
- **Construction errors** — `MissingTrpEndpoint` returned by `Tx3ClientBuilder.build()` when no TRP endpoint has been supplied via `trp(options)` or `trpEndpoint(url)`.
- **TRP transport errors** — network, HTTP status, JSON-RPC error, malformed response.
- **Resolution errors** — missing required params, arg coercion failures.
- **Signing errors** — invalid key, hash mismatch, address binding failure.
- **Submission errors** — submit-hash mismatch, server rejection.
- **Polling errors** — terminal stage failure, timeout.

Discriminating these cases MUST be possible without string matching. The Rust SDK uses a single `Error` enum (`rust-sdk/sdks/src/facade.rs`). TypeScript SDKs SHOULD use an error class hierarchy rooted at `TrpError` / `Tx3Error`.

### Recoverable errors vs. invariant violations

Errors in the SDK's public API MUST be the language's idiomatic recoverable shape (`Result` / `Either` / typed exception / multi-return). The SDK MUST NOT unconditionally panic, abort, or throw uncatchable errors on inputs the caller can legitimately get wrong — including misspelled name lookups against the declared protocol. Std-lib precedent (`HashMap::get`, `env::var`, dictionary lookups across languages) is the bar.

The exception is codegen-generated wrappers ([codegen/generated-surface.md](../codegen/generated-surface.md)). In the codegen flow the embedded protocol is the contract — the declared transactions, profiles, and parties are by construction the only valid names. A codegen wrapper MAY collapse the SDK's recoverable lookup errors into the language's invariant-violation mechanism (`unwrap`/`panic` in Rust, `throw` of an assertion-style error in TS/Python, etc.) on the grounds that a failure indicates the caller passed a name outside the codegen-declared set. Wrappers MUST NOT collapse errors from `resolve` / `sign` / `submit` / `wait*` — those are genuine runtime failures.
