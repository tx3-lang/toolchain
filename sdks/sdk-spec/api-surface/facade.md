# Facade

The facade is the high-level orchestration layer that drives the full transaction lifecycle through a builder chain. This file covers the facade client, parties, profiles, and wait modes — all tightly coupled concerns.

---

## &sect;3.3 &mdash; High-Level Facade

An SDK MUST expose a single high-level client (the **facade**) that owns the **deconstructed** protocol — per-transaction TIR envelopes, the set of declared party names, the selected profile (if any) — plus the runtime state (TRP client, bound parties, env overrides). The same client backs both consumption flows; only construction differs.

### Construction (MUST)

The facade MUST be constructible only through a **builder** (`Tx3ClientBuilder` per [glossary](../glossary.md)). The public, infallible constructor of the facade itself is the builder's terminal `build()` method; the SDK MUST NOT expose a separate public way to materialize the facade client. This includes both the dynamic and codegen flows — both go through the builder, which absorbs the protocol-decomposition work.

The builder is seeded one of two ways — both produce the same builder shape and reach `build()` along the same path. Branching downstream of seeding is non-conformant.

- **From a loaded `Protocol`** — `Protocol.client()` (idiomatic spelling) returns a fresh `Tx3ClientBuilder` seeded with the protocol. `Protocol` is the entry point for loading TII data; the loaders (`fromFile`, `fromString`, `fromJson` — see [tii.md](tii.md)) live there, not on the facade. This is the dynamic flow.
- **From decomposed parts** — `Tx3ClientBuilder.fromParts(transactions, profiles, knownParties)` seeds the builder directly with the runtime essentials: per-transaction `TirEnvelope`s, per-profile `{environment, parties}` maps, and the set of declared party names. This is the entry point used by codegen-generated bindings, which embed only those fragments at codegen time instead of the entire TII document (see [codegen/generated-surface.md](../codegen/generated-surface.md)).

The builder MUST expose:

- **Mandatory TRP settings**, named without a `with_` / `with` prefix — `trp(options)` to set the full `ClientOptions` shape, and `trpEndpoint(url)` as a shorthand for endpoint-only. (Mandatory setters MUST NOT carry the optional-setter prefix.)
- **Optional settings**, named with the host language's `with` prefix — at minimum `withProfile(name)`, `withParty(name, party)`, `withParties(iterable)`, `withHeader(key, value)`, and `withEnvValue(key, value)`. Setters MUST be infallible (chain-returning, never `Result<…>`).
- **`build()`**, the single fallible terminal. Returns the language's idiomatic recoverable-error type with named variants on miss: `MissingTrpEndpoint` if no endpoint was supplied, `UnknownProfile` if the selected profile is not declared by the protocol, `UnknownParty` if any bound party is not declared (see [errors.md](errors.md)).

Builders absorb all fallible validation — chains stay fluent up to `build()`. The client MUST NOT retain a reference to the source `Protocol` once `build()` returns.

There is exactly one client type per SDK — a parallel "dynamic" vs. "codegen" client is non-conformant. Codegen-generated wrappers MUST compose this builder (see [codegen/generated-surface.md](../codegen/generated-surface.md)); the SDK MUST NOT ship a separate parts-based public constructor for codegen to call.

### Lifecycle chain (MUST)

The minimum shape:

```
Protocol.fromFile("protocol.tii")
    .client()
    .trpEndpoint("https://trp.example")
    .withProfile("preprod")
    .withParty("sender", Party.signer(signer))
    .withParty("receiver", Party.address("addr_..."))
    .build()                                       -> Tx3Client
    .tx("transfer")
        .arg("quantity", 10_000_000)
        .resolve()                                 -> ResolvedTx
        .sign()                                    -> SignedTx
        .submit()                                  -> SubmittedTx
        .waitForConfirmed(PollConfig.default())    -> TxStatus
```

The step names and the order MUST NOT change. Async/await, promises, and ownership-vs-reference semantics MUST follow the host language idioms.

### Builder is source-agnostic (MUST)

`TxBuilder` (the value returned by `.tx(name)`) MUST hold its resolve inputs directly — the TIR envelope, the env values from the selected profile (with any builder-supplied overrides folded in), the bound parties, the typed args — and MUST drive a single `resolve()` path. There MUST NOT be a tagged variant over "where the TIR came from"; producing the inputs is the builder's job, not the runtime transaction builder's.

### Name lookups (MUST)

`tx(name)` on the built client MUST return the language's idiomatic recoverable-error type with an `UnknownTx` variant on miss; `build()` on the client builder MUST return `UnknownProfile` / `UnknownParty` / `MissingTrpEndpoint` per [errors.md](errors.md). Neither MUST unconditionally panic/throw — std-lib precedent for name lookup against a known set is recoverable (`HashMap::get`, `env::var`, dictionary access). Codegen-generated wrappers MAY collapse these into language-level invariant violations because there the embedded protocol is the contract (see [codegen/generated-surface.md](../codegen/generated-surface.md)).

The builder's optional setters (`withProfile`, `withParty`, …) MUST NOT validate the supplied name eagerly — name validation is deferred to `build()` so that chains stay fluent. The SDK MAY validate at `build()` time in any order, but every failure mode MUST surface as a distinct named variant.

### Late-binding parties (MAY)

The built client MAY also expose `withParty(name, party)` / `withParties(iterable)` for **late binding** after `build()` — useful when, for example, a user logs in after the client is already in scope. These late-binding methods MUST validate against the protocol's declared parties (returning `UnknownParty` on miss) and MUST behave identically to the same setters on the builder. Profile selection is **builder-only**: SDKs MUST NOT expose a profile-switching method on the built client. Switching profiles requires constructing a new client.

SDKs MUST also expose `withPartyUnchecked(name, party)` on both the builder and the built client — an infallible variant that skips the name lookup. This is the codegen entry point: generated wrappers materialize one typed method per declared party and route through `withPartyUnchecked`, since the name is baked into the method at codegen time. Hand-written / dynamic code SHOULD use the validated `withParty`.

### Construction options (MUST)

The mandatory TRP setters MUST accept the TRP `ClientOptions` shape (endpoint + optional headers + room for future fields). The `trpEndpoint(url)` shorthand is provided for the bare-endpoint common case; it MUST be equivalent to supplying `ClientOptions { endpoint: url }`. See [trp.md](trp.md).

*Rust reference:* `tx3_sdk::Tx3ClientBuilder`, `tx3_sdk::Tx3Client`, `TxBuilder`, `ResolvedTx`, `SignedTx`, `SubmittedTx`, `Profile` (`rust-sdk/sdks/src/facade.rs`); the builder is obtained from `tx3_sdk::tii::Protocol::client`.

---

## &sect;3.4 &mdash; Parties

An SDK MUST expose two party constructors:

- `Party.address(address: string)` — read-only party, provides only an address.
- `Party.signer(signer)` — signer party; the address is read from the signer.

Parties are attached by name (`withParty(name, party)`) — on the client builder during construction, and optionally on the built client for late binding ([§3.3 Late-binding parties](facade.md#late-binding-parties-may)). When an invocation is built, **the SDK MUST automatically inject each attached party's address into the invocation args under the party's name** (matching case-insensitively). Users may still override any arg explicitly via `.arg(...)`.

If `name` is not declared by the protocol, the builder MUST report it as `UnknownParty` at `build()` time; the optional late-binding method on the built client MUST report `UnknownParty` eagerly at the call site (see [§3.3 Name lookups](facade.md#name-lookups-must)). In neither case may the failure be deferred to `resolve()`.

*Rust reference:* `tx3_sdk::facade::Party`, `Tx3ClientBuilder::with_party`, `Tx3Client::with_party`, `TxBuilder::resolve` (injection logic).

---

## &sect;3.5b &mdash; Manual Witness Attachment

An SDK MUST allow a consumer to attach pre-computed `TxWitness` values to a `ResolvedTx` between `resolve()` and `sign()`. The method is named per host-language convention:

- Rust: `ResolvedTx::add_witness(self, witness: TxWitness) -> Self`
- TypeScript: `ResolvedTx.addWitness(witness: TxWitness): this`
- Go: `(*ResolvedTx) AddWitness(w TxWitness) *ResolvedTx`
- Python: `ResolvedTx.add_witness(self, witness: TxWitness) -> ResolvedTx`

Input is the existing public `Witness` type defined in [§3.5](signers.md). The method MAY be called zero, one, or many times. The SDK MUST NOT verify the witness against the tx hash; that binding is enforced by TRP.

When `sign()` is called, the resulting `SignedTx` MUST include all manually attached witnesses in the TRP `SubmitParams.witnesses` array, appended after witnesses produced by registered signer parties, in attach order. `sign()` MUST succeed when zero registered signers are configured and at least one witness has been manually attached.

This is the canonical mechanism for wallet-app integrations: a consumer hands `ResolvedTx.txHex` (or `hash`) to an external wallet, gets back a witness, attaches it, and proceeds with the standard chain.

*Rust reference:* `tx3_sdk::facade::ResolvedTx::add_witness` (`rust-sdk/sdks/src/facade.rs`).

---

## &sect;3.6 &mdash; Profiles and Environment Overrides

An SDK MUST allow selecting a single profile name on the client builder via `withProfile(name)`. The selected profile MUST be applied — its environment values and party-address overrides — to every invocation created by the built client. If `name` is not declared by the protocol, `build()` MUST surface an `UnknownProfile` error per [§3.3 Name lookups](facade.md#name-lookups-must).

Profile selection is **builder-only**: a built client MUST NOT expose a method to switch profiles. Switching profiles requires constructing a new client through a fresh builder. (Rust enforces this by removing `with_profile` from `Tx3Client`; other languages SHOULD follow the same restriction.)

An SDK MUST also expose `withEnvValue(key, value)` on the builder for one-off environment overrides. Values supplied via `withEnvValue` MUST be merged on top of the selected profile's environment at resolve time — later writes win, and explicit overrides win over profile defaults. This is the canonical mechanism for adjusting individual env values (e.g. a network selector) without forking a new profile.

---

## &sect;3.7 &mdash; Wait Modes

A `SubmittedTx` MUST expose two wait methods:

- `waitForConfirmed(pollConfig) -> TxStatus` — resolves when the tx reaches `Confirmed` *or* `Finalized`.
- `waitForFinalized(pollConfig) -> TxStatus` — resolves only when the tx reaches `Finalized`.

Both MUST:

- Fail fast with a terminal error if the tx reaches `Dropped` or `RolledBack`.
- Fail with a timeout error after `attempts` polls spaced by `delay`.
- Accept a `PollConfig` with defaults `attempts = 20`, `delay = 5s`.

*Rust reference:* `tx3_sdk::facade::SubmittedTx::wait_for_confirmed` / `wait_for_finalized`, `PollConfig::default`.
