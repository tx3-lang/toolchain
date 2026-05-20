# &sect;3.5 &mdash; Signers

An SDK MUST expose:

1. **A `Signer` interface/trait/abstract class.** It MUST have two operations: `address() -> string` and `sign(request: SignRequest) -> Witness`. Users MUST be able to implement their own signers by conforming to this interface.
2. **A built-in `CardanoSigner`** that derives keys using the Cardano BIP32 path `m/1852'/1815'/0'/0/0` and can be constructed from at least a mnemonic phrase + address.
3. **A built-in `Ed25519Signer`** — a generic raw-key signer constructed from a 32-byte private key + address.

A `SignRequest` MUST carry both the `txHashHex` (hex of the bound tx hash) and the `txCborHex` (hex of the full tx CBOR). The SDK MUST populate both fields on every call. Hash-based signers (Cardano, Ed25519) read `txHashHex`; tx-based signers (e.g. CIP-30 wallet adapters that need the full tx body) read `txCborHex`. Field names follow the host language's casing convention.

A `Witness` MUST carry: the public key (hex envelope), the signature (hex envelope), and a witness type (at least `vkey`).

SDKs SHOULD additionally offer `from_hex` constructors where it's natural in the host language.

External witnesses produced outside any registered `Signer` are attached to a `ResolvedTx` via `addWitness` — see [facade §3.5b](facade.md).

*Rust reference:* `tx3_sdk::facade::signer::{Signer, CardanoSigner, Ed25519Signer}`.
