# Generated Surface

This page defines the **minimum public symbols** generated bindings MUST expose. Idiomatic spelling per language (casing, exported vs. unexported, module layout) is at the plugin author's discretion — the contract is on identity and role, not naming.

The reference shape is `sdks/web-sdk/.trix/client-lib/protocol.ts.hbs`. Match its symbol roles; spell them however the host language wants.

## Embedding vs. runtime loading (MUST)

Codegen and runtime `Protocol.fromFile` (see [api-surface/tii.md](../api-surface/tii.md)) are **parallel** TII-loading paths, not layered ones. A consumer that uses generated bindings does not need a `.tii` file at runtime; a consumer that does not use codegen uses `Protocol.fromFile`.

Generated bindings MUST embed everything the SDK builder needs at runtime — and nothing more. The runtime essentials are:

- **Per-transaction TIR envelopes** — for every entry in `tii.transactions`, the `tir.content` / `tir.encoding` / `tir.version` triple. Each TIR envelope MUST be emitted as a single named item (a constant, lazy static, or the host language's nearest equivalent — e.g. `pub static TRANSFER_TIR: LazyLock<TirEnvelope>` in Rust, an exported `const` in TypeScript, a module-level binding in Python/Go). Templates MUST NOT bury per-tx TIR triples inside a constructor function — one named item per transaction keeps the embedded data discoverable, deduplicated, and free for advanced callers to reference directly.
- **Per-profile data** — for every entry in `tii.profiles`, the `environment` + `parties` payload. Each profile MUST be emitted as a single named item (a static, lazy static, or the host language's nearest equivalent). The named items MAY be private — they exist to feed the wrapper's constructor, not as public surface. Templates MAY embed a small per-profile JSON blob inside that named item and decode it through the SDK's `Profile` deserializer at first access; per-profile struct literals are equally compliant. Templates MUST NOT bundle profiles into a single `PROFILES_JSON` blob parsed at construction.

  Additionally, when `tii.profiles` is non-empty, bindings MUST emit a typed **Profile enum** — one variant per profile, named after the profile key in idiomatic case (e.g. `pub enum Profile { Local, Preprod }` in Rust, `enum Profile { Local, Preprod }` or a union of string literal types in TypeScript). This enum is the **required argument** to the wrapper's constructor (see [Top-level facade](#top-level-facade-must)) — profile selection is type-checked, not string-based. The single-profile case is treated identically to the multi-profile case (one variant, but uniform shape). When `tii.profiles` is empty, the enum is omitted and the constructor takes no profile argument.

The declared party names are *not* embedded. Wrappers materialize one typed `with_<party>` setter per declared party (see [*Per-party*](#per-party-must) below) and route those through the SDK's `withPartyUnchecked` entry points, which skip the name lookup because the name is baked into the method at codegen time. The `knownParties` argument to `Tx3ClientBuilder.fromParts` is passed empty.

The wrapper hands those fragments (plus the empty party-name set) to `Tx3ClientBuilder.fromParts` and continues through the same SDK builder the dynamic flow uses. There is one builder shape and one `build()` path; only the seeding differs.

Generated bindings MUST NOT:

- Embed the entire TII document. Param schemas, environment schemas, and other TII metadata are codegen-time inputs for shape generation — they are not runtime essentials and embedding them inflates the generated crate. See *Prohibitions* below.
- Call `Protocol.fromFile` / `Protocol.fromJson` (or any other runtime TII loader) internally — the SDK's `Tx3ClientBuilder.fromParts` is the codegen entry point, not `Protocol`.
- Ship the source `.tii` file as a sibling of the rendered output.
- Re-derive TIR or profile data at runtime from anything other than the embedded constants.

Protocol identity (name, version, target TII version) MUST also appear as constants — see *Protocol identity* below — but those are small and serve introspection, not facade construction.

The embedded fragments are the entire runtime carry-forward from TII; once codegen runs, the `.tii` artifact is no longer needed by the consumer.

## Per-transaction (MUST)

For every entry in `tii.transactions`, the bindings MUST expose:

1. **A `Params` type** — a named record whose fields correspond 1:1 to `params.properties`, with field types resolved via `schemaTypeFor` (see [renderer-contract.md](renderer-contract.md)). The shape MUST be discoverable and type-checked by the host language's tooling.
2. **A typed transaction method on the wrapper** — named after the transaction (idiomatic case), taking a `Params` value, delegating to the wrapped client's `tx(name)`, and applying the typed args. Returns the SDK's `TxBuilder`; the caller drives `.resolve() → .sign() → .submit() → .wait*()` from there.

The typed method MUST NOT inline the TIR or branch on tx name internally — it delegates to the wrapped facade client, which receives every transaction's TIR through the `transactions` map passed to `Tx3ClientBuilder.fromParts`.

Per-transaction TIR envelopes are emitted as named items — see [Embedding vs. runtime loading](#embedding-vs-runtime-loading-must). One named item per transaction; bundling them into a private map constructor is non-conformant.

## Per-party (MUST)

For every entry in `tii.parties`, the bindings MUST expose a typed setter method on the post-`build()` `Client`. The method is named `with_<party>` (idiomatic case per language) and takes a single `Party` argument — the party *name* is baked into the method, not passed as a string. The method MUST delegate to the SDK's `withPartyUnchecked(name, party)` entry on the underlying `Tx3Client`, supplying the hardcoded party name. SDKs MUST expose `withPartyUnchecked` on both `Tx3ClientBuilder` and `Tx3Client` so codegen-generated wrappers can skip the name lookup the validated `withParty` performs.

The wrapper MUST NOT expose a generic `withParty(name, party)` setter — every party is materialized as its own typed method. This makes party names a type-checked concern (autocompletion, no string typos) and matches the parity between typed per-transaction methods and the protocol's declared transactions.

Because the typed methods route through `withPartyUnchecked`, the embedded party-name set is unnecessary for the codegen flow — see [Embedding vs. runtime loading](#embedding-vs-runtime-loading-must). The validated `withParty` is still the canonical path for hand-written / dynamic code and is the only one SDKs expose to non-generated callers.

## Top-level facade (MUST)

The generated `Client` MUST be a thin **wrapper around the runtime SDK's facade client** (`Tx3Client` per [api-surface/facade.md §3.3](../api-surface/facade.md)) — typically a newtype / struct embedding / composition, depending on host language idioms. The wrapper exposes exactly one construction entry point and no pre-build configuration layer:

- **Constructor** — `Client.new(options, profile)` when `tii.profiles` is non-empty; `Client.new(options)` otherwise. The profile argument is the typed Profile enum (see [Profiles](#profiles-and-environment-must)). Internally the constructor seeds `Tx3ClientBuilder.fromParts(transactions, profiles, knownParties)` with the embedded fragments, sets the TRP options, calls `withProfile` with the enum's underlying name, and calls `build()`. The SDK builder is the only construction path — the wrapper MUST NOT call `Protocol.fromJson` / `Protocol.client()` at runtime or any other facade entry point.
- **Profile is locked in at construction.** The wrapper MUST NOT expose a method to switch profiles on the built `Client`. Switching profiles requires constructing a new `Client`.
- **`ClientOptions` shape.** The wrapper accepts the runtime SDK's `ClientOptions` (endpoint + optional auth headers — see [api-surface/trp.md](../api-surface/trp.md)). It MUST NOT narrow to a bare endpoint string. Headers are passed through `ClientOptions.headers`; the wrapper MUST NOT expose a separate header-setter method.
- **No env-override surface.** The wrapper MUST NOT expose `withEnvValue` (or equivalent). One-off env overrides are a dynamic-flow concern — consumers who need them drop down to the SDK's `Tx3ClientBuilder` directly.
- **No wrapper builder.** The wrapper MUST NOT expose a separate `ClientBuilder` type or a `Client.builder(...)` factory. All pre-build configuration the wrapper offers is captured by the constructor arguments; everything else is post-build (typed per-party setters, typed per-transaction methods).
- **Typed per-tx methods** — one typed per-transaction method per `tii.transactions` entry (see *Per-transaction* above).
- **Typed per-party setters** — one typed per-party setter per `tii.parties` entry (see *Per-party* above), exposed on the built `Client` for late binding.

The wrapper MUST NOT re-implement state the SDK already owns. Parties, signers, profile selection, env folding and overrides, the resolve/sign/submit/wait chain, party-address injection, and the error hierarchy ([api-surface/](../api-surface/)) all live in the runtime SDK and MUST be delegated to. The only code unique to the generated wrapper is the typed shape of per-transaction methods, per-transaction params, per-party setters, the typed Profile enum, and the embedded protocol fragments.

### Error handling in the wrapper

Where the SDK facade and its builder return recoverable errors on name lookups and missing-endpoint validation ([api-surface/errors.md](../api-surface/errors.md)), the wrapper MAY collapse those into the host language's invariant-violation mechanism (`unwrap`/`panic` in Rust, `throw` of an assertion-style error in TS/Python, etc.). In the codegen flow the embedded protocol is the contract: the embedded transactions, profiles, and parties are by construction the only valid names, so a lookup miss indicates the caller passed a name outside the codegen-declared set — a programmer error, not a recoverable case. The wrapper MUST still require a TRP endpoint from the caller; passing one is the caller's responsibility, but if the builder reports `MissingTrpEndpoint` the wrapper MAY collapse that too as an invariant violation. Wrappers MUST NOT collapse errors from `resolve` / `sign` / `submit` / `wait*` — those are real runtime failures and MUST surface as the SDK's normal error types.

## Protocol identity (MUST)

Bindings MUST emit constants for `tii.protocol.{name,version}` and the target TII version (see [versioning.md](versioning.md)). Generated artifacts MUST be self-describing — a consumer reading the generated file alone MUST be able to tell which protocol, which protocol version, and which TII schema version it was rendered against.

## Profiles and environment (MUST)

Profiles MUST be embedded in the generated output so consumers can instantiate the facade against a named profile without supplying a `.tii` file at runtime. The minimum surface:

- **Embedded profile data** — one named item per profile (see [Embedding vs. runtime loading](#embedding-vs-runtime-loading-must)). Each named item embeds a small per-profile JSON blob and decodes it through the SDK's `Profile` deserializer at first access, or assembles the `Profile` value from a per-profile struct literal. The named items MAY be private — they exist to feed the wrapper's constructor. **Parsers MUST live in the SDK runtime, not in the template** — templates only embed raw JSON or call SDK constructors.
- **Typed Profile enum** — when `tii.profiles` is non-empty, bindings MUST emit a typed Profile enum with one variant per profile (see *Per-profile data* in [Embedding vs. runtime loading](#embedding-vs-runtime-loading-must)). This enum is the type-checked replacement for string-based profile selection.
- **Environment schema (optional convenience)** — when `tii.environment` is present, plugins MAY emit a typed struct (using `schemaTypeFor`) or a raw schema constant for introspection; this is compliant either way. It is *not* required for facade construction.
- **Facade integration** — the wrapper's constructor MUST accept the typed Profile enum and use it to call the SDK builder's `withProfile` internally. Env overrides are *not* exposed by the wrapper (see [Top-level facade](#top-level-facade-must)); consumers who need them use the SDK builder directly.

Profiles are **not** optional metadata; they are how a generated `Client` knows *where* to send transactions. Without them, the generated facade is incomplete — the consumer would have to hand-supply TRP endpoints and party addresses that the TII already declares. Protocols with `tii.profiles` empty are an edge case: the wrapper's constructor degrades to taking no profile argument, and the SDK builder is called without `withProfile`.

## Prohibitions

- **No raw TII passthrough.** Consumers MUST NOT receive the TII JSON as an opaque blob.
- **No oversized embeds.** Templates MUST embed only the runtime-essential fragments (per-tx TIR triples, per-profile data, party names) — the param schemas, environment schemas, and other TII subtrees consumed at codegen time MUST NOT appear in the generated output. Carrying the whole TII document into the runtime crate inflates binary size without benefit.
- **No third-party runtime dependencies.** Only the host SDK and the language's standard library.
- **No client state or lifecycle logic.** TRP client construction, party storage, profile selection, env/party merging, the resolve/sign/submit/wait chain — all live in the runtime SDK. The wrapper composes the SDK's facade client and adds only the typed per-protocol surface (params, transaction methods, embedded data).
- **No parsers.** Templates embed profile data verbatim as small per-profile JSON blobs and delegate decoding to the SDK's `Profile` deserializer. Shape-decoding logic that would live identically across every generated client belongs in the SDK.
- **No runtime `Protocol` round-trips.** Wrappers MUST seed the builder via `Tx3ClientBuilder.fromParts`; calling `Protocol.fromJson` / `Protocol.client()` at runtime is non-conformant. Both the dynamic and codegen flows share the same builder and the same `build()` validation — only the seeding entry point differs.
- **No embedded party-name set.** Typed `with_<party>` setters route through `withPartyUnchecked`, so the validated `withParty` lookup never runs in the codegen flow. Embedding the party-name list is dead weight.

## Known drift

All four first-party plugins target the `v1beta0` data shape and satisfy the per-transaction, top-level facade, protocol-identity, and profiles/environment requirements above. The remaining gap is plugin tagging: the Go and Python plugins have been ported but still need their immutable `codegen-v1beta0` tags cut (see [versioning.md](versioning.md) and [plugin-layout.md](plugin-layout.md)).

Status is tracked in the [parity matrix](../../parity-matrix.md).
