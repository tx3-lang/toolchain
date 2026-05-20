# Generated Surface

This page defines the **minimum public symbols** generated bindings MUST expose. Idiomatic spelling per language (casing, exported vs. unexported, module layout) is at the plugin author's discretion — the contract is on identity and role, not naming.

The reference shape is `sdks/web-sdk/.trix/client-lib/protocol.ts.hbs`. Match its symbol roles; spell them however the host language wants.

## Embedding vs. runtime loading (MUST)

Codegen and runtime `Protocol.fromFile` (see [api-surface/tii.md](../api-surface/tii.md)) are **parallel** TII-loading paths, not layered ones. A consumer that uses generated bindings does not need a `.tii` file at runtime; a consumer that does not use codegen uses `Protocol.fromFile`.

Generated bindings MUST embed everything they need from the TII at codegen time:

- TIR envelopes (per transaction) — see *Per-transaction* below.
- Protocol identity and profiles/environment — see *Protocol identity* and *Profiles* below.

Generated bindings MUST NOT:

- Call `Protocol.fromFile` (or any other runtime TII loader) internally.
- Ship the source `.tii` file as a sibling of the rendered output.
- Re-derive TIR or profile data at runtime from anything other than the embedded constants.

The embedded constants are the entire carry-forward from TII; once codegen runs, the `.tii` artifact is no longer needed by the consumer.

## Per-transaction (MUST)

For every entry in `tii.transactions`, the bindings MUST expose:

1. **A `Params` type** — a named record whose fields correspond 1:1 to `params.properties`, with field types resolved via `schemaTypeFor` (see [renderer-contract.md](renderer-contract.md)). The shape MUST be discoverable and type-checked by the host language's tooling.
2. **A `TIR` constant** — an embedding of `tii.transactions.<name>.tir` (verbatim `content`, `encoding`, `version`). Consumers pass this to the runtime SDK's TRP `resolve`.
3. **A transaction method** — async, named after the transaction (idiomatic case), taking a `Params` value and delegating to the runtime SDK's TRP `resolve` with the corresponding `TIR` constant.

## Top-level facade (MUST)

A single entry point (typically `Client`) that:

- Accepts the runtime SDK's TRP client options (or wraps an existing TRP client).
- Exposes one transaction method per `tii.transactions` entry.
- Exposes a `submit` operation delegating to the runtime SDK's TRP `submit`.

The facade MUST be a thin pass-through. Parties, signers, wait-modes, and error hierarchy live in the runtime SDK ([api-surface/](../api-surface/)) and MUST NOT be re-implemented here.

## Protocol identity (MUST)

Bindings MUST emit constants for `tii.protocol.{name,version}` and the target TII version (see [versioning.md](versioning.md)). Generated artifacts MUST be self-describing — a consumer reading the generated file alone MUST be able to tell which protocol, which protocol version, and which TII schema version it was rendered against.

## Profiles and environment (MUST)

Bindings MUST embed `tii.profiles` and `tii.environment` so consumers can instantiate the facade against a named profile without supplying a `.tii` file at runtime. The minimum surface:

- **Per-profile constant** — for each entry in `tii.profiles`, a named, addressable value containing that profile's `environment` and `parties` payload (verbatim from TII).
- **Environment schema** — when `tii.environment` is present, a constant or type derived from it. Plugins MAY emit it as a typed struct (using `schemaTypeFor`) or as the raw schema object; either is compliant as long as consumers can introspect or validate against it.
- **Facade integration** — the top-level `Client` MUST accept a profile selector (by name) and apply the corresponding environment + parties at construction time. The shape of the selector (string argument, builder method, constructor overload) is idiomatic.

The shape of the per-profile constant (struct, map literal, JSON value, dataclass) MAY be whatever is idiomatic for the language. What matters is that the data is statically present in the generated output and reachable through the facade.

Profiles and environment are **not** optional metadata; they are how a generated `Client` knows *where* to send transactions. Without them, the generated facade is incomplete — the consumer would have to hand-supply TRP endpoints and party addresses that the TII already declares.

## Prohibitions

- **No raw TII passthrough.** Consumers MUST NOT receive the TII JSON as an opaque blob.
- **No third-party runtime dependencies.** Only the host SDK and the language's standard library.
- **No business logic.** Retry, signing, party management belong in the runtime SDK.

## Known drift

All four first-party plugins target the `v1beta0` data shape and satisfy the per-transaction, top-level facade, protocol-identity, and profiles/environment requirements above. The remaining gap is plugin tagging: the Go and Python plugins have been ported but still need their immutable `codegen-v1beta0` tags cut (see [versioning.md](versioning.md) and [plugin-layout.md](plugin-layout.md)).

Status is tracked in the [parity matrix](../../parity-matrix.md).
