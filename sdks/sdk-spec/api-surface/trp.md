# &sect;3.2 &mdash; Low-Level TRP Client

An SDK MUST expose a low-level TRP client for advanced users who do not want to use the facade. The client MUST accept a `ClientOptions` shape at construction — endpoint + optional custom HTTP headers + room for forward-compatible additions — and MUST NOT narrow the public construction surface to a bare endpoint string. Custom headers are how hosted TRPs authenticate, and the options shape must stay open to future connection settings (timeouts, TLS, retry config). The same requirement applies cross-cuttingly: any higher-level constructor that accepts TRP settings — the facade ([§3.3](facade.md)), the codegen-generated wrapper ([codegen/generated-surface.md](../codegen/generated-surface.md)) — MUST accept `ClientOptions`, not a bare endpoint.

The client exposes at minimum:

- `resolve(params) -> ResolveResponse`
- `submit(params) -> SubmitResponse`
- `checkStatus(hashes) -> StatusResponse`

`checkStatus` is what powers the wait modes in the [facade](facade.md#37--wait-modes). An SDK that only implements `resolve` + `submit` is **incomplete**.

*Rust reference:* `tx3_sdk::trp::Client` (`rust-sdk/sdks/src/trp/`).
*Web SDK:* `web-sdk/sdks/src/trp/client.ts` — full parity as of v1.0.0.
