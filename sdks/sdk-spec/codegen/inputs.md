# Inputs

A codegen plugin renders against a **TII file** (Transaction Invocation Interface) — the JSON artifact `tx3c build --emit tii` produces. The renderer parses it and exposes it under the key `tii` (see [renderer-contract.md](renderer-contract.md)).

The authoritative TII schema is `tx3/bin/tx3c/src/tii/types.rs` (`TiiFile` and friends, version `TII_VERSION`). This page does not duplicate the schema — it lists the *guarantees and prohibitions* templates can rely on.

## Templates MAY read

Any field that `types.rs` declares as required for the targeted `TII_VERSION`. The most common entry points:

- `tii.protocol.{name,version,scope}` — protocol identity. SHOULD be emitted as constants in the output (see [generated-surface.md](generated-surface.md)).
- `tii.transactions` — the per-tx loop. Each value has a `tir` envelope, a `params` JSON Schema, and an optional `description`.
- `tii.profiles`, `tii.parties`, `tii.environment`, `tii.components.schemas` — available but OPTIONAL for templates to consume.

## Templates MUST NOT

- Rely on undocumented top-level keys. Future TII versions MAY add fields; plugins MUST tolerate unknown keys.
- Special-case `tir.encoding` or `tir.version` values other than the ones documented for the targeted `TII_VERSION`.
- Depend on map iteration order in `transactions`, `profiles`, or `parties`.

## Version compatibility

A plugin targets exactly one TII version (see [versioning.md](versioning.md)). The renderer does **not** validate `tii.version` today, so plugins SHOULD emit a header comment naming the target version so mismatches are visible in the generated diff.

## Shared fixture

The canonical input every render-fixture test consumes is `sdks/sdk-spec/test-vectors/transfer/transfer.tii`. See [testing.md](testing.md).
