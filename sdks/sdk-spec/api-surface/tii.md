# &sect;3.1 &mdash; Protocol Loading (TII)

An SDK MUST load a TII document into an in-memory `Protocol` from at least:

- a file path (`Protocol.from_file(path)` / `Protocol.fromFile(path)`)
- a byte blob / string (`Protocol.from_bytes(bytes)` / `Protocol.fromString(json)`)

The `Protocol` object MUST expose enough metadata for the facade to validate invocations (known parties, known transactions, parameter names and types).

*Rust reference:* `tx3_sdk::tii::Protocol::from_file` (`rust-sdk/sdks/src/tii/`).
