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
2. **A `TIR` accessor** — a value or function exposing `tii.transactions.<name>.tir` (verbatim `content`, `encoding`, `version`). The transactions map passed to the SDK facade's parts-based constructor is built from these accessors at runtime in `Client.new` (see *Top-level facade* below).
3. **A typed transaction method on the wrapper** — named after the transaction (idiomatic case), taking a `Params` value, delegating to the wrapped client's `tx(name)`, and applying the typed args. Returns the SDK's `TxBuilder`; the caller drives `.resolve() → .sign() → .submit() → .wait*()` from there.

The typed method MUST NOT inline the TIR or branch on tx name internally — it delegates to the wrapped facade client, which already owns the embedded transactions map.

## Top-level facade (MUST)

The generated `Client` MUST be a thin **wrapper around the runtime SDK's facade client** (`Tx3Client` per [api-surface/facade.md §3.3](../api-surface/facade.md)) — typically a newtype / struct embedding / composition, depending on host language idioms. The wrapper:

- Constructs the inner client via its parts-based constructor (`Tx3Client.fromParts(transactions, profiles, knownParties, trpClient)`), supplying the values the template embedded at codegen time.
- Accepts the runtime SDK's `ClientOptions` at construction (endpoint + optional auth headers — see [api-surface/trp.md](../api-surface/trp.md)). It MUST NOT narrow to a bare endpoint string.
- Delegates `withProfile(name)`, `withParty(name, party)`, and the rest of the lifecycle surface straight through to the inner client.
- Adds one typed per-transaction method per `tii.transactions` entry (see *Per-transaction* above).

The wrapper MUST NOT re-implement state the SDK already owns. Parties, signers, profile selection, env folding, the resolve/sign/submit/wait chain, party-address injection, and the error hierarchy ([api-surface/](../api-surface/)) all live in the runtime SDK and MUST be delegated to. The only code unique to the generated wrapper is the typed shape of per-transaction methods and per-transaction params, the embedded data, and three short delegating methods (`new` / `withProfile` / `withParty`).

### Error handling in the wrapper

Where the SDK facade returns recoverable errors on name lookups ([api-surface/errors.md](../api-surface/errors.md)), the wrapper MAY collapse those into the host language's invariant-violation mechanism (`unwrap`/`panic` in Rust, `throw` of an assertion-style error in TS/Python, etc.). In the codegen flow the embedded protocol is the contract: the embedded transactions, profiles, and parties are by construction the only valid names, so a lookup miss indicates the caller passed a name outside the codegen-declared set — a programmer error, not a recoverable case. Wrappers MUST NOT collapse errors from `resolve` / `sign` / `submit` / `wait*` — those are real runtime failures and MUST surface as the SDK's normal error types.

## Protocol identity (MUST)

Bindings MUST emit constants for `tii.protocol.{name,version}` and the target TII version (see [versioning.md](versioning.md)). Generated artifacts MUST be self-describing — a consumer reading the generated file alone MUST be able to tell which protocol, which protocol version, and which TII schema version it was rendered against.

## Profiles and environment (MUST)

Bindings MUST embed `tii.profiles` and `tii.environment` so consumers can instantiate the facade against a named profile without supplying a `.tii` file at runtime. The minimum surface:

- **Embedded profile data** — the `environment` and `parties` payload of every `tii.profiles` entry MUST be statically present in the generated output. The template SHOULD embed `tii.profiles` as a JSON string constant and delegate parsing to a runtime SDK function (`Profile.loadAll(json)` per [api-surface/facade.md](../api-surface/facade.md)); per-profile struct literals are also compliant. **Parsers MUST live in the SDK runtime, not in the template** — when a new protocol-data shape is added, the SDK gains a parser method and templates only embed the raw JSON.
- **Environment schema** — when `tii.environment` is present, a constant or type derived from it. Plugins MAY emit it as a typed struct (using `schemaTypeFor`) or as the raw schema object; either is compliant as long as consumers can introspect or validate against it.
- **Facade integration** — the wrapper MUST accept a profile selector (by name) and apply the corresponding environment + parties through the wrapped client's `withProfile`. The shape of the selector (string argument, builder method, constructor overload) is idiomatic.

Profiles and environment are **not** optional metadata; they are how a generated `Client` knows *where* to send transactions. Without them, the generated facade is incomplete — the consumer would have to hand-supply TRP endpoints and party addresses that the TII already declares.

## Prohibitions

- **No raw TII passthrough.** Consumers MUST NOT receive the TII JSON as an opaque blob.
- **No third-party runtime dependencies.** Only the host SDK and the language's standard library.
- **No client state or lifecycle logic.** TRP client construction, party storage, profile selection, env/party merging, the resolve/sign/submit/wait chain — all live in the runtime SDK. The wrapper composes the SDK's facade client and adds only the typed per-protocol surface (params, transaction methods, embedded data).
- **No parsers.** Templates embed protocol data verbatim and delegate decoding to SDK functions (`Profile.loadAll`, etc.). Shape-decoding logic that would live identically across every generated client belongs in the SDK.

## Known drift

All four first-party plugins target the `v1beta0` data shape and satisfy the per-transaction, top-level facade, protocol-identity, and profiles/environment requirements above. The remaining gap is plugin tagging: the Go and Python plugins have been ported but still need their immutable `codegen-v1beta0` tags cut (see [versioning.md](versioning.md) and [plugin-layout.md](plugin-layout.md)).

Status is tracked in the [parity matrix](../../parity-matrix.md).
