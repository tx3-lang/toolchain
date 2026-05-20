# &sect;3.9 &mdash; Argument Marshalling

An SDK MUST accept native host-language values for transaction args (integers, strings, booleans, byte arrays, addresses) and marshal them into the TRP wire format. Argument names MUST be matched case-insensitively against the protocol's declared params.

The SDK SHOULD expose an `ArgValue`-equivalent type for users who need to construct tagged values explicitly (useful for `UtxoRef`, `UtxoSet`, etc.).

*Rust reference:* `tx3_sdk::core::ArgMap`. *Web reference:* `web-sdk/sdks/src/core/args.ts`.
