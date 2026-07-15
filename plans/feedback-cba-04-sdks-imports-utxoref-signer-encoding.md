# Plan: SDK import paths, UtxoRef, Ed25519Signer, bytes-vs-list encoding

Status: **open / not started**
Scope: `sdks/rust-sdk/` and `sdks/web-sdk/` (Python/Go audit too).
Origin: user feedback doc (Rust + TS + Hydra-heads).

## Context

A. **Rust imports.**
   - `UtxoRef` not imported in generated `lib.rs`; needs
     `use tx3_sdk::core::{ArgMap, TirEncoding, TirEnvelope, UtxoRef};`.
   - `signer` not found in `tx3_sdk` (example code).
   - `CardanoSigner` imported as `tx3_sdk::signer::CardanoSigner` but
     should be `tx3_sdk::CardanoSigner`.
   These are template/visibility issues in the rust-sdk codegen
   templates (see `plans/sdk-codegen-v1beta0-migration.md`).

B. **Type mismatch / encoding.** Rust pilot & ship name types mismatch
   → `Error: (-32005) value is not bytes: [1,1]`. Same shape as
   Hydra-heads Rust init `(-32005) value is not bytes: [1,2]`. Likely a
   `List<Bytes>` vs raw-bytes encoding bug in the SDK serialization.

C. **TS signing.** `Ed25519Signer.fromMnemonic` doesn't sign, but
   `CardanoSigner.fromMnemonic` does. Either `Ed25519Signer` is broken
   or the snippet should use `CardanoSigner`.

## Approach

1. Fix rust-sdk codegen templates: add `UtxoRef` to the `lib.rs` import
   block; correct the `CardanoSigner` path; fix the `signer` example.
   Coordinate with the `codegen-v1beta0` migration (the templates being
   authored there should include these fixes from the start).
2. Trace the bytes-vs-list encoding: where `List<Bytes>` (or
   `participants: vec![vec![1,2]]`) is serialized, confirm it emits a
   CBOR list of byte-strings, not a bare byte-string. Add a unit test
   covering Hydra `init` `participants`/`parties`/`head_id` and Asteria
   pilot/ship names.
3. In web-sdk, fix or remove `Ed25519Signer.fromMnemonic`; ensure
   snippets use a working signer (`CardanoSigner.fromMnemonic` or
   `.fromHex`).

## References

- `plans/sdk-codegen-v1beta0-migration.md` — the template contract and
  recommended order (rust-sdk first).
- `sdks/AGENTS.md`.
- Hydra-heads Rust `init` snippet (doc) for the `[1,2]` repro.

## Verification

- Rust-sdk generated example builds (`cargo build`) with `UtxoRef` and
  `CardanoSigner` imports correct.
- Hydra `init` (TS/Python/Rust) no longer returns
  `(-32005) target type not supported: List` / `value is not bytes`.
- Asteria `create_ship` pilot/ship names accept hex-string params
  without the `[1,1]` error.
- TS `Ed25519Signer.fromMnemonic` signs, or snippets use
  `CardanoSigner`.

## Depends on / unblocks

- Pairs with the `codegen-v1beta0` migration. Fixes Hydra `init` across
  all three SDKs (also referenced in cluster 6).
