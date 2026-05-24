# &sect;3.1 &mdash; Protocol Loading (TII)

An SDK MUST load a TII document into an in-memory `Protocol` from at least:

- a file path (`Protocol.from_file(path)` / `Protocol.fromFile(path)`)
- a byte blob / string (`Protocol.from_bytes(bytes)` / `Protocol.fromString(json)`)

The `Protocol` object MUST expose its transactions, declared parties, profiles, and environment as readable accessors. The facade ([§3.3](facade.md)) reads these once inside `Tx3ClientBuilder.build()` to deconstruct the protocol into the client's state, then drops the `Protocol` reference. Per-invocation querying of `Protocol` is not part of the facade flow.

The `Protocol` object MUST also expose a `client()` accessor (idiomatic spelling per host language) that returns a fresh `Tx3ClientBuilder` seeded with the protocol. This is the single bridge from TII loading to the facade — see [§3.3 Construction](facade.md#construction-must).

*Rust reference:* `tx3_sdk::tii::Protocol::from_file`, `tx3_sdk::tii::Protocol::client` (`rust-sdk/sdks/src/tii/`).
