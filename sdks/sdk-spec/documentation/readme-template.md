# SDK README Template

Every SDK's `README.md` MUST contain the following sections, in this order. The exact wording is flexible; the structure is not.

---

## Required sections

### 1. Title and badges

- Package name and version badge.
- CI status badge.
- Link to the canonical Tx3 docs site: **https://docs.txpipe.io/tx3**. Every SDK README MUST link here as the single Tx3 reference URL.

### 2. What is Tx3

One paragraph (2-4 sentences) explaining what Tx3 is and what this SDK does. Do not assume the reader knows anything about UTxO, TRP, or TII. Link to the [Tx3 docs](https://docs.txpipe.io/tx3) for deeper context.

### 3. Installation

The single command needed to add the SDK to a project:

- Rust: `cargo add tx3-sdk`
- TypeScript: `npm install tx3-sdk`
- Python: `pip install tx3-sdk` (or `uv add tx3-sdk`)
- etc.

### 4. Quick start

A complete, copy-pasteable code example that:

1. Loads a protocol from a `.tii` file
2. Creates a `Tx3Client` with a TRP endpoint
3. Configures a profile and parties
4. Builds, resolves, signs, and submits a transaction
5. Waits for confirmation

This example MUST compile/run if the user has a TRP endpoint and test credentials. Annotate each step with a brief comment.

### 5. Concepts

A brief section mapping the SDK's types to the [glossary](../glossary.md) terms. At minimum cover: `Protocol`, `Tx3Client`, `TxBuilder`, `Party`, `Signer`, `SignRequest`, `ResolvedTx`, `SignedTx`, `SubmittedTx`, `PollConfig`.

### 6. Advanced usage

- How to use the low-level TRP client directly (for users who don't want the facade).
- How to implement a custom `Signer` (taking a `SignRequest` per [§3.5](../api-surface/signers.md)).
- How to attach an externally-produced witness via `addWitness` (per [§3.5b](../api-surface/facade.md)).
- Any SDK-specific extras (build-time plugins, framework integrations, wallet bridges).

### 7. Tx3 protocol compatibility

A line declaring which TRP protocol version and TII schema version this SDK speaks. Per [versioning](../versioning.md), this is required.

### 8. License

Apache-2.0 (matching the existing SDKs).

---

## Optional sections

- **Contributing** — contribution guidelines, if the SDK accepts external PRs.
- **API reference link** — link to generated docs (docs.rs, TypeDoc site, etc.).
- **Changelog** — or link to `CHANGELOG.md`.
