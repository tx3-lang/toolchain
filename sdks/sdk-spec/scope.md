# Scope

## Mission

A Tx3 SDK is an **ergonomic, idiomatic client library** that lets a developer in its target language:

1. Load a Tx3 protocol definition (a `.tii` artifact).
2. Configure parties and signers for that protocol.
3. Invoke a transaction by name with arguments.
4. Resolve the invocation into a concrete chain transaction via a TRP server.
5. Sign the transaction using the configured signer parties.
6. Submit it back through TRP.
7. Wait for the transaction to reach a desired chain stage (confirmed, finalized).

Everything else — wallet UI, fee estimation outside TRP, chain indexing, key storage — is **out of scope**. See Non-Goals.

## Recommended Surface (SHOULD)

- **Re-exports at the crate/package root.** A user importing the SDK MUST be able to reach `Tx3Client`, `Party`, `CardanoSigner`, `Ed25519Signer`, and `PollConfig` from the top-level module without drilling into submodules. (Rust SDK does this in `lib.rs`.)
- **Builder ergonomics.** `withParties(iterable)` for bulk attachment. `args(map)` on the TxBuilder alongside `arg(k, v)`.
- **Introspection on ResolvedTx.** Expose `hash` / `signingHash` / `txHex`. Feeding externally-signed witnesses back in is required — see [`facade.md` §3.5b](api-surface/facade.md).
- **Inline rustdoc / TSDoc / docstrings** on every public item, with at least one usage example. See the [docstring strategy](documentation/docstrings.md) for details.

## Optional Surface (MAY)

- **Codegen plugins** — per-language template sets that emit typed bindings from a `.tii` artifact. See [codegen/](codegen/) for the plugin contract. The Web SDK additionally ships build-tool integrations (`vite-plugin-tx3`, `rollup-plugin-tx3`, `next-tx3`) that drive the plugin from a bundler. Plugins and integrations are *additions*, never substitutes, for the runtime surface in the [API surface](api-surface/) section.
- **Framework integrations** (Next.js, React hooks, Actix/Axum middleware).
- **CLI scaffolders** (e.g. `install-tx3-nextjs`).
- **Test helpers** (fake TRP server, deterministic signer, protocol fixtures).

If an SDK ships one of these, it MUST still meet the [required API surface](api-surface/) in full.

## Non-Goals

A Tx3 SDK is **not**:

- A wallet or key manager. Key material handling beyond constructing a `Signer` from raw bytes / mnemonic is out of scope.
- A chain indexer. Historical tx queries belong elsewhere.
- A fee estimator. Fee logic lives in TRP.
- A `.tx3` compiler. Compilation is the Tx3 toolchain's job.
- A persistence layer. SDKs are stateless modulo the loaded `Protocol` and configured parties.

## Compliance Checklist

To claim a row of `docs/parity-matrix.md`, an SDK MUST demonstrate each capability with either a passing test or a documented example. Quick checklist per SDK:

- [ ] `Protocol.fromFile` works on `sdk-spec/test-vectors/transfer/transfer.tii`
- [ ] Low-level `TRPClient.resolve`, `submit`, `checkStatus` all implemented
- [ ] `Tx3Client` facade: `withProfile`, `withParty`, `tx(name).arg(...).resolve()`
- [ ] `Party.address` and `Party.signer` both work
- [ ] `CardanoSigner` from mnemonic + address
- [ ] `Ed25519Signer` from 32-byte private key + address
- [ ] `ResolvedTx.sign() -> SignedTx.submit() -> SubmittedTx`
- [ ] `waitForConfirmed(PollConfig.default())` and `waitForFinalized(...)` both reach terminal states
- [ ] Error type discriminates all categories in the [error model](api-surface/errors.md)
- [ ] Top-level re-exports per the recommended surface section
- [ ] Unit tests cover every component per the [testing strategy](testing/)
- [ ] End-to-end (e2e) tests pass against a live TRP endpoint per the [testing strategy](testing/)
- [ ] CI defines a single unified workflow with separate unit and e2e jobs per the [CI workflow policy](testing/ci-workflows.md)
- [ ] CI e2e job fails fast when required env/secrets are missing, and fail-on-error when configured
- [ ] Release workflow is tag-driven and aligned with [release-policy.md](release-policy.md)
- [ ] Core SDK package version follows fleet-wide `MAJOR.MINOR` sync policy from [release-policy.md](release-policy.md)
- [ ] Every public symbol has a docstring per the [documentation requirements](documentation/)
