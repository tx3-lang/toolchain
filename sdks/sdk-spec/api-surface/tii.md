# &sect;3.1 &mdash; Protocol Loading (TII)

An SDK MUST load a TII document into an in-memory `Protocol` from at least:

- a file path (`Protocol.from_file(path)` / `Protocol.fromFile(path)`)
- a byte blob / string (`Protocol.from_bytes(bytes)` / `Protocol.fromString(json)`)

The `Protocol` object MUST expose its transactions, declared parties, profiles, and environment as readable accessors — the facade ([§3.3](facade.md)) reads these once at `Tx3Client.new(protocol, ...)` time to deconstruct the protocol into its own state, then drops the `Protocol` reference. Per-invocation querying of `Protocol` is not part of the facade flow.

*Rust reference:* `tx3_sdk::tii::Protocol::from_file` (`rust-sdk/sdks/src/tii/`).
