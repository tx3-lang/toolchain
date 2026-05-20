# Tx3 SDK Parity Matrix

**Purpose:** snapshot of which required capabilities from `sdk-spec/` are implemented in each SDK. Agents update this file any time they ship, remove, or audit a capability. If a cell and reality disagree, reality wins — fix the cell.

**Legend**

| Symbol | Meaning |
|--------|---------|
| ✅     | Implemented and covered by docs/tests/examples. Link the source file. |
| 🚧     | Partial, WIP, or missing a sub-requirement. Add a note. |
| ❌     | Not implemented. |
| —      | Not applicable to this SDK (must be justified in notes). |

**Snapshot date:** 2026-04-27. Update this date whenever you re-audit.

---

## Capability matrix

Capability references are to `sdk-spec/api-surface/`.

| # | Capability                           | `rust-sdk` | `web-sdk` | `go-sdk` | `python-sdk` | Notes |
|---|--------------------------------------|------------|-----------|----------|--------------|-------|
| 3.1 | `Protocol.fromFile` + `fromString` + `fromJson` | ✅ [`rust-sdk/sdk/src/tii/`](../rust-sdk/sdk/src/tii/) | ✅ [`web-sdk/sdk/src/tii/protocol.ts`](../web-sdk/sdk/src/tii/protocol.ts) | ✅ [`go-sdk/sdk/tii/protocol.go`](../go-sdk/sdk/tii/protocol.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/tii/protocol.py`](../python-sdk/sdk/src/tx3_sdk/tii/protocol.py) | Web: `fromFile` is Node-only. Go: `FromFile`, `FromString`, `FromBytes`. Python: `from_file`, `from_string`, `from_json`. |
| 3.2 | TRP `resolve`                        | ✅ [`rust-sdk/sdk/src/trp/`](../rust-sdk/sdk/src/trp/) | ✅ [`web-sdk/sdk/src/trp/client.ts`](../web-sdk/sdk/src/trp/client.ts) | ✅ [`go-sdk/sdk/trp/client.go`](../go-sdk/sdk/trp/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/trp/client.py`](../python-sdk/sdk/src/tx3_sdk/trp/client.py) | |
| 3.2 | TRP `submit`                         | ✅ | ✅ | ✅ [`go-sdk/sdk/trp/client.go`](../go-sdk/sdk/trp/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/trp/client.py`](../python-sdk/sdk/src/tx3_sdk/trp/client.py) | |
| 3.2 | TRP `checkStatus`                    | ✅ | ✅ [`web-sdk/sdk/src/trp/client.ts`](../web-sdk/sdk/src/trp/client.ts) | ✅ [`go-sdk/sdk/trp/client.go`](../go-sdk/sdk/trp/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/trp/client.py`](../python-sdk/sdk/src/tx3_sdk/trp/client.py) | |
| 3.3 | Facade `Tx3Client` + builder chain   | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/client.ts`](../web-sdk/sdk/src/facade/client.ts) | ✅ [`go-sdk/sdk/facade/client.go`](../go-sdk/sdk/facade/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client.py`](../python-sdk/sdk/src/tx3_sdk/facade/client.py) | Go uses `context.Context` for async ops. |
| 3.4 | `Party.address` / `Party.signer`     | ✅ | ✅ [`web-sdk/sdk/src/facade/party.ts`](../web-sdk/sdk/src/facade/party.ts) | ✅ [`go-sdk/sdk/facade/party.go`](../go-sdk/sdk/facade/party.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/party.py`](../python-sdk/sdk/src/tx3_sdk/facade/party.py) | Go: `AddressParty()` / `SignerParty()`. |
| 3.4 | Auto-inject party addresses into args | ✅ | ✅ [`web-sdk/sdk/src/facade/builder.ts`](../web-sdk/sdk/src/facade/builder.ts) | ✅ [`go-sdk/sdk/facade/builder.go`](../go-sdk/sdk/facade/builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/builder.py) | |
| 3.5 | `Signer` interface                   | ✅ (`trait Signer`) | ✅ [`web-sdk/sdk/src/signer/signer.ts`](../web-sdk/sdk/src/signer/signer.ts) | ✅ [`go-sdk/sdk/signer/signer.go`](../go-sdk/sdk/signer/signer.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/signer/signer.py`](../python-sdk/sdk/src/tx3_sdk/signer/signer.py) | Go interface: `Address()`, `Sign()`. |
| 3.5 | `CardanoSigner` (BIP32 1852'/1815')  | ✅ | ✅ [`web-sdk/sdk/src/signer/cardano.ts`](../web-sdk/sdk/src/signer/cardano.ts) | ✅ [`go-sdk/sdk/signer/cardano.go`](../go-sdk/sdk/signer/cardano.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/signer/cardano.py`](../python-sdk/sdk/src/tx3_sdk/signer/cardano.py) | Go uses `filippo.io/edwards25519` + `golang.org/x/crypto`. |
| 3.5 | `Ed25519Signer`                      | ✅ | ✅ [`web-sdk/sdk/src/signer/ed25519.ts`](../web-sdk/sdk/src/signer/ed25519.ts) | ✅ [`go-sdk/sdk/signer/ed25519.go`](../go-sdk/sdk/signer/ed25519.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/signer/ed25519.py`](../python-sdk/sdk/src/tx3_sdk/signer/ed25519.py) | Go uses stdlib `crypto/ed25519`. |
| 3.5b | Manual witness attachment (`addWitness` on `ResolvedTx`) | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/resolved.ts`](../web-sdk/sdk/src/facade/resolved.ts) | ✅ [`go-sdk/sdk/facade/resolved.go`](../go-sdk/sdk/facade/resolved.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/resolved.py`](../python-sdk/sdk/src/tx3_sdk/facade/resolved.py) | TxWitness input only. Web-sdk also ships [`Cip30Signer`](../web-sdk/sdk/src/signer/cip30.ts) + `cip30Party()` as a sibling signer module. |
| 3.6 | `withProfile`                        | ✅ | ✅ [`web-sdk/sdk/src/facade/client.ts`](../web-sdk/sdk/src/facade/client.ts) | ✅ [`go-sdk/sdk/facade/client.go`](../go-sdk/sdk/facade/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client.py`](../python-sdk/sdk/src/tx3_sdk/facade/client.py) | |
| 3.7 | `waitForConfirmed` / `waitForFinalized` + `PollConfig` | ✅ | ✅ [`web-sdk/sdk/src/facade/submitted.ts`](../web-sdk/sdk/src/facade/submitted.ts) | ✅ [`go-sdk/sdk/facade/submitted.go`](../go-sdk/sdk/facade/submitted.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/submitted.py`](../python-sdk/sdk/src/tx3_sdk/facade/submitted.py) | Defaults: 20 attempts, 5 s. Go respects `context.Context` cancellation. |
| 3.8 | Discriminated error model            | ✅ (`facade::Error` enum) | ✅ Full hierarchy via `instanceof` | ✅ Per-domain marker interfaces + `errors.As()` | ✅ Rooted at `Tx3Error` with category subclasses | Go: `TiiError`, `TrpError`, `SignerError`, `FacadeError` marker interfaces. |
| 3.9 | Argument marshalling                 | ✅ (`core::ArgMap`) | ✅ [`web-sdk/sdk/src/core/args.ts`](../web-sdk/sdk/src/core/args.ts) | ✅ [`go-sdk/sdk/core/args.go`](../go-sdk/sdk/core/args.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/core/args.py`](../python-sdk/sdk/src/tx3_sdk/core/args.py) | Go: `ArgValue` tagged union + `CoerceArg()` for native types. |
| §4  | Top-level re-exports                 | ✅ [`lib.rs`](../rust-sdk/sdk/src/lib.rs) | ✅ [`web-sdk/sdk/src/index.ts`](../web-sdk/sdk/src/index.ts) | ✅ [`go-sdk/sdk/tx3sdk.go`](../go-sdk/sdk/tx3sdk.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/__init__.py`](../python-sdk/sdk/src/tx3_sdk/__init__.py) | Go: type aliases + wrapper functions at package root. |

---

## Codegen plugin parity

Capability references are to `sdk-spec/codegen/`. Codegen is an **optional** SDK capability; an `—` here means the SDK has not opted in and is not required to.

| # | Capability | `rust-sdk` | `web-sdk` | `go-sdk` | `python-sdk` | Notes |
|---|---|---|---|---|---|---|
| C.1 | `.trix/client-lib/` template set present | ✅ [`rust-sdk/.trix/client-lib/`](../rust-sdk/.trix/client-lib/) | ✅ [`web-sdk/.trix/client-lib/`](../web-sdk/.trix/client-lib/) | ✅ [`go-sdk/.trix/client-lib/`](../go-sdk/.trix/client-lib/) | ✅ [`python-sdk/.trix/client-lib/`](../python-sdk/.trix/client-lib/) | All four SDKs ship a plugin at the canonical convention path. |
| C.2 | Targets current TII version (`v1beta0`) | ✅ | ✅ | 🚧 templates still on legacy `bindgen-v1alpha2` data shape | 🚧 templates still on legacy `bindgen-v1alpha2` data shape | Rust/Web use `tii.transactions` + `schemaTypeFor`; Go/Python use flat `transactions` + `typeFor`. |
| C.3a | Per-tx `Params` + `TIR` constant + facade method | ✅ | ✅ | 🚧 needs C.2 port | 🚧 needs C.2 port | Core per-transaction surface. |
| C.3b | Protocol identity constants (name, version, target TII version) | 🚧 emits name+version, missing TII version | 🚧 missing | ❌ | ❌ | [generated-surface.md §Protocol identity](sdk-spec/codegen/generated-surface.md). |
| C.3c | Profiles + environment embedded + wired into facade | 🚧 emits `profiles()` but no facade wiring | ❌ | 🚧 partial via `Default*` constants | 🚧 partial via `Default*` constants | [generated-surface.md §Profiles and environment](sdk-spec/codegen/generated-surface.md). No plugin fully complies. |
| C.3d | No runtime `Protocol.fromFile` from generated code | ✅ | ✅ | ✅ | ✅ | Embedding-only constraint; all current plugins satisfy by construction. |
| C.4 | Plugin tag immutability + `codegen-v<TII>` naming | ✅ `codegen-v1beta0` | ✅ `codegen-v1beta0` | 🚧 | 🚧 | Tag policy defined in [codegen/plugin-layout.md](sdk-spec/codegen/plugin-layout.md). |
| C.5 | Render-fixture test ([testing.md](sdk-spec/codegen/testing.md)) | 🚧 [`rust-sdk/sdk/tests/codegen.rs`](../rust-sdk/sdk/tests/codegen.rs) — runs `tx3c codegen` but does not compile output | ❌ | ❌ | ❌ | Reference pattern exists; needs compile-of-output step and replication. |

---

## Cross-cutting policy parity

| Policy capability | `rust-sdk` | `web-sdk` | `go-sdk` | `python-sdk` | Notes |
|---|---|---|---|---|---|
| Unified CI workflow policy (`testing/ci-workflows.md`) | ✅ [`rust-sdk/.github/workflows/ci.yml`](../rust-sdk/.github/workflows/ci.yml) | ✅ [`web-sdk/.github/workflows/ci.yml`](../web-sdk/.github/workflows/ci.yml) | ✅ [`go-sdk/.github/workflows/ci.yml`](../go-sdk/.github/workflows/ci.yml) | ✅ [`python-sdk/.github/workflows/ci.yml`](../python-sdk/.github/workflows/ci.yml) | Unit/e2e are selected by explicit language-idiomatic selectors (Rust e2e targets, Web `test:unit`/`test:e2e`, Go `e2e` build tag, Python `e2e` marker). |
| Release policy (`release-policy.md`) | ✅ [`rust-sdk/.github/workflows/release.yml`](../rust-sdk/.github/workflows/release.yml) | ✅ [`web-sdk/.github/workflows/release.yml`](../web-sdk/.github/workflows/release.yml) | ✅ [`go-sdk/.github/workflows/release.yml`](../go-sdk/.github/workflows/release.yml) | ✅ [`python-sdk/.github/workflows/release.yml`](../python-sdk/.github/workflows/release.yml) | Core SDK packages only. Rust/Web/Python use `vMAJOR.MINOR.PATCH`; Go uses `sdk/vMAJOR.MINOR.PATCH`. |

---

## Per-SDK summary

### `rust-sdk` (v0.9.2)

Reference implementation. All required capabilities in §3 are implemented. The main follow-ups are polish / stabilization items for 1.0, not parity gaps:

- Consider expanding the built-in `Signer` set (hardware wallet shims, external-signer bridge).
- Lock down the `core::ArgMap` API before 1.0.

### `web-sdk` (`tx3-sdk` v1.0.0)

All §3 required capabilities are now implemented. The v1.0.0 rewrite (branch `spec-refactor`) delivers:

- **Runtime TII loading** (`Protocol.fromFile`, `fromString`, `fromJson`) with full `ParamType` schema decoder.
- **Full TRP client** (`resolve`, `submit` returning `SubmitResponse`, `checkStatus`, `dumpLogs`, `peekPending`, `peekInflight`).
- **Signer module** (`Ed25519Signer` via `@noble/curves`, `CardanoSigner` via `@stricahq/bip32ed25519` with `m/1852'/1815'/0'/0/0` derivation).
- **Facade** (`Tx3Client`, `TxBuilder`, `ResolvedTx`, `SignedTx`, `SubmittedTx`, `PollConfig`, `Party`).
- **Full error hierarchy** (`Tx3Error` root, `TrpError`, `TiiError`, `SignerError`, `ResolutionError`, `SubmissionError`, `PollingError` — all `instanceof`-discriminated).
- **Top-level + subpath re-exports** (`tx3-sdk`, `tx3-sdk/trp`, `tx3-sdk/tii`, `tx3-sdk/signer`).
- **CIP-30 signer** (`Cip30Signer`, `cip30Party(api)`) shipped from `tx3-sdk/signer` alongside `CardanoSigner` / `Ed25519Signer`. Backed by [`cborg`](https://www.npmjs.com/package/cborg) for witness-set decoding. Single-key wallets only; multi-key wallets call `decodeWitnessSet` directly and attach each via `addWitness`.

Build-time codegen integrations (`vite-plugin-tx3`, `rollup-plugin-tx3`, `next-tx3`) drive the `.trix/client-lib/` plugin from a bundler. The plugin contract itself is now spec'd under [sdk-spec/codegen/](sdk-spec/codegen/); the web-sdk plugin is already on `codegen-v1beta0`.

### `python-sdk` (`tx3-sdk` v1.0.0)

The Python SDK was rewritten against `sdk-spec/` and now implements all required §3 capabilities:

- **Runtime TII loading** via `Protocol.from_file`, `from_string`, and `from_json`.
- **Full TRP client** (`resolve`, `submit`, `check_status`) with typed transport/RPC errors.
- **Facade chain** (`Tx3Client`, `TxBuilder`, `ResolvedTx`, `SignedTx`, `SubmittedTx`) including profile and party handling.
- **Signer module** (`Signer`, `Ed25519Signer`, `CardanoSigner`) with `vkey` witness output.
- **Wait modes + polling** (`wait_for_confirmed`, `wait_for_finalized`, `PollConfig.default()`).
- **Top-level package re-exports** from `tx3_sdk`.

---

## How to update this file

1. Audit a capability by reading both the spec and the SDK source. Don't trust the existing cell.
2. Update the cell (✅/🚧/❌) and, if ✅, link the actual source file path.
3. If you found a new sub-capability worth tracking, add a row rather than overloading an existing one.
4. Bump the **Snapshot date** above.
5. If you close or open a gap, mention it in the per-SDK summary.

The `audit-parity` skill automates steps 1–4. Use it when in doubt.
