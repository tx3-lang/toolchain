# &sect;3.2 &mdash; Low-Level TRP Client

An SDK MUST expose a low-level TRP client for advanced users who do not want to use the facade. The client takes `ClientOptions` (endpoint, optional headers) and exposes at minimum:

- `resolve(params) -> ResolveResponse`
- `submit(params) -> SubmitResponse`
- `checkStatus(hashes) -> StatusResponse`

`checkStatus` is what powers the wait modes in the [facade](facade.md#37--wait-modes). An SDK that only implements `resolve` + `submit` is **incomplete**.

*Rust reference:* `tx3_sdk::trp::Client` (`rust-sdk/sdks/src/trp/`).
*Web SDK:* `web-sdk/sdks/src/trp/client.ts` — full parity as of v1.0.0.
