# Facade

The facade is the high-level orchestration layer that drives the full transaction lifecycle through a builder chain. This file covers the facade client, parties, profiles, and wait modes — all tightly coupled concerns.

---

## &sect;3.3 &mdash; High-Level Facade

An SDK MUST expose a single high-level client (the **facade**) that owns the **deconstructed** protocol — per-transaction TIR envelopes, named profiles, the set of declared party names — plus the runtime state (TRP client, bound parties, selected profile). The same client backs both consumption flows; only construction differs.

### Construction (MUST)

The facade MUST expose two constructors:

- **From a loaded protocol** — `new(protocol, trpClient)`, with convenience variants for the common loaders (`fromFile(path, trpClient)`, `fromString(json, trpClient)`, `fromJson(value, trpClient)`). Deconstructs the `Protocol` into the parts the client stores and drops it; the client MUST NOT retain a reference to the `Protocol` object once construction returns.
- **From deconstructed parts** — `fromParts(transactions, profiles, knownParties, trpClient)` (or an equivalent options object / builder if the part count grows). This is the entry point used by codegen-generated bindings, which embed the parts at codegen time.

Both constructors produce the same client value; downstream code MUST NOT branch on which constructor was used. There is exactly one client type per SDK — a parallel "dynamic" vs. "codegen" client is non-conformant.

### Lifecycle chain (MUST)

The minimum shape:

```
Tx3Client.new(protocol, trpClient)
    .withProfile("preprod")
    .withParty("sender", Party.signer(signer))
    .withParty("receiver", Party.address("addr_..."))
    .tx("transfer")
        .arg("quantity", 10_000_000)
        .resolve()           -> ResolvedTx
        .sign()              -> SignedTx
        .submit()            -> SubmittedTx
        .waitForConfirmed(PollConfig.default())  -> TxStatus
```

The step names and the order MUST NOT change. Async/await, promises, and ownership-vs-reference semantics MUST follow the host language idioms.

### Builder is source-agnostic (MUST)

`TxBuilder` (the value returned by `.tx(name)`) MUST hold its resolve inputs directly — the TIR envelope, the env values from the selected profile, the bound parties, the typed args — and MUST drive a single `resolve()` path. There MUST NOT be a tagged variant over "where the TIR came from"; producing the inputs is the constructor's job, not the builder's.

### Name lookups (MUST)

`withProfile(name)`, `withParty(name, party)`, and `tx(name)` MUST return the language's idiomatic recoverable-error type (`Result<_, Error>`, `Either`, typed exception, multi-return) with named variants on miss: `UnknownProfile`, `UnknownParty`, `UnknownTx` (see [errors.md](errors.md)). They MUST NOT unconditionally panic/throw — std-lib precedent for name lookup against a known set is recoverable (`HashMap::get`, `env::var`, dictionary access). Codegen-generated wrappers MAY collapse these into language-level invariant violations because there the embedded protocol is the contract (see [codegen/generated-surface.md](../codegen/generated-surface.md)).

### Construction options (MUST)

Any constructor that accepts TRP connection settings MUST accept the TRP `ClientOptions` shape (endpoint + optional headers + room for future fields) rather than a bare endpoint string. See [trp.md](trp.md).

*Rust reference:* `tx3_sdk::Tx3Client`, `TxBuilder`, `ResolvedTx`, `SignedTx`, `SubmittedTx`, `Profile` (`rust-sdk/sdks/src/facade.rs`).

---

## &sect;3.4 &mdash; Parties

An SDK MUST expose two party constructors:

- `Party.address(address: string)` — read-only party, provides only an address.
- `Party.signer(signer)` — signer party; the address is read from the signer.

Parties are attached to the facade client by name (`withParty(name, party)`). When an invocation is built, **the SDK MUST automatically inject each attached party's address into the invocation args under the party's name** (matching case-insensitively). Users may still override any arg explicitly via `.arg(...)`.

If `name` is not declared by the protocol, `withParty()` MUST return an `UnknownParty` error per [§3.3 Name lookups](facade.md#name-lookups-must) — failing eagerly at the binding call, not deferred to `resolve()`.

*Rust reference:* `tx3_sdk::facade::Party`, `Tx3Client::with_party`, `TxBuilder::resolve` (injection logic).

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

## &sect;3.6 &mdash; Profiles

An SDK MUST allow setting a single profile name on the facade client via `withProfile(name)`. The selected profile MUST be applied — its environment values and party-address overrides — to every invocation created by that client. If `name` is not declared by the protocol, `withProfile()` MUST return an `UnknownProfile` error per [§3.3 Name lookups](facade.md#name-lookups-must).

Changing the profile produces a new logical client (Rust does this via `with_profile` consuming `self`; other languages are free to use a setter).

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
