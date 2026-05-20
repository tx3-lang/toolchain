# Facade

The facade is the high-level orchestration layer that ties a `Protocol` to a `TRP client` and drives the full transaction lifecycle through a builder chain. This file covers the facade client, parties, profiles, and wait modes — all tightly coupled concerns.

---

## &sect;3.3 &mdash; High-Level Facade

An SDK MUST expose a high-level client (the **facade**) that ties a `Protocol` to a `TRP client` and produces transactions via a builder chain. The minimum shape:

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

The chain is the canonical shape. Async/await, promises, and ownership-vs-reference semantics MUST follow the host language idioms — but the step names and the order MUST NOT change.

*Rust reference:* `tx3_sdk::facade::Tx3Client`, `TxBuilder`, `ResolvedTx`, `SignedTx`, `SubmittedTx` (`rust-sdk/sdks/src/facade.rs`).

---

## &sect;3.4 &mdash; Parties

An SDK MUST expose two party constructors:

- `Party.address(address: string)` — read-only party, provides only an address.
- `Party.signer(signer)` — signer party; the address is read from the signer.

Parties are attached to the facade client by name (`withParty(name, party)`). When an invocation is built, **the SDK MUST automatically inject each attached party's address into the invocation args under the party's name** (matching case-insensitively). Users may still override any arg explicitly via `.arg(...)`.

If a party name is attached that is not declared in the loaded `Protocol`, `resolve()` MUST fail with a clear `UnknownParty` error.

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

An SDK MUST allow setting a single profile name on the facade client via `withProfile(name)`. That profile MUST be applied to every invocation created by that client. Changing the profile produces a new logical client (Rust does this via `with_profile` consuming `self`; other languages are free to use a setter).

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
