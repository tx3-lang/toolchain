# &sect;3.8 &mdash; Error Model

An SDK MUST expose a single top-level error type (or error hierarchy) that distinguishes at least:

- **TII / protocol errors** — bad TII file, unknown tx name, unknown party.
- **TRP transport errors** — network, HTTP status, JSON-RPC error, malformed response.
- **Resolution errors** — missing required params, arg coercion failures.
- **Signing errors** — invalid key, hash mismatch, address binding failure.
- **Submission errors** — submit-hash mismatch, server rejection.
- **Polling errors** — terminal stage failure, timeout.

Discriminating these cases MUST be possible without string matching. The Rust SDK uses a single `Error` enum (`rust-sdk/sdks/src/facade.rs`). TypeScript SDKs SHOULD use an error class hierarchy rooted at `TrpError` / `Tx3Error`.
