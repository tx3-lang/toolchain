# Tx3 SDK Parity Matrix

**Purpose:** snapshot of which required capabilities from `sdk-spec/` are implemented in each SDK. Agents update this file any time they ship, remove, or audit a capability. If a cell and reality disagree, reality wins — fix the cell.

**Legend**

| Symbol | Meaning |
|--------|---------|
| ✅     | Implemented and covered by docs/tests/examples. Link the source file. |
| 🚧     | Partial, WIP, or missing a sub-requirement. Add a note. |
| ❌     | Not implemented. |
| —      | Not applicable to this SDK (must be justified in notes). |

**Snapshot date:** 2026-06-19 (complex-arg **wire-encoding** shipped in all four SDKs — sprint complex-types WU-01/WU-04: the `TaggedArg` self-describing tagged form in `core/trp/v1beta0/trp.json` + `api-surface/args.md`, shared oracle `test-vectors/complex-types/wire-vectors.json`; each SDK's `into_resolve_request` now type-directed-encodes complex args, with records reshaped to declared-order fields. Coordinated breaking `ParamType` bump pending release WU-07). Prior snapshot 2026-06-12 (complex-type model parity: all four SDKs reworked their `ParamType` interpretation to the canonical model in `api-surface/args.md` — trailing-name core `$ref` matching across `tii#/$defs/` + legacy `core#` forms, distinct list/tuple/map/record/variant kinds carrying inner types, never-throw `unknown` fallback, component-ref resolution. Shared fixture: `sdk-spec/test-vectors/complex-types/complex.tii`). Prior snapshot 2026-05-24 (post-merge of the unified-builder ports across rust/web/python/go; see [rust-sdk#38](https://github.com/tx3-lang/rust-sdk/pull/38), [web-sdk#29](https://github.com/tx3-lang/web-sdk/pull/29), [python-sdk#13](https://github.com/tx3-lang/python-sdk/pull/13), [go-sdk#10](https://github.com/tx3-lang/go-sdk/pull/10)).

---

## Capability matrix

Capability references are to `sdk-spec/api-surface/`.

| # | Capability                           | `rust-sdk` | `web-sdk` | `go-sdk` | `python-sdk` | Notes |
|---|--------------------------------------|------------|-----------|----------|--------------|-------|
| 3.1 | `Protocol.fromFile` + `fromString` + `fromJson` | ✅ [`rust-sdk/sdk/src/tii/`](../rust-sdk/sdk/src/tii/) | ✅ [`web-sdk/sdk/src/tii/protocol.ts`](../web-sdk/sdk/src/tii/protocol.ts) | ✅ [`go-sdk/sdk/tii/protocol.go`](../go-sdk/sdk/tii/protocol.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/tii/protocol.py`](../python-sdk/sdk/src/tx3_sdk/tii/protocol.py) | Web: `fromFile` is Node-only. Go: `FromFile`, `FromString`, `FromBytes`. Python: `from_file`, `from_string`, `from_json`. |
| 3.2 | TRP `resolve`                        | ✅ [`rust-sdk/sdk/src/trp/`](../rust-sdk/sdk/src/trp/) | ✅ [`web-sdk/sdk/src/trp/client.ts`](../web-sdk/sdk/src/trp/client.ts) | ✅ [`go-sdk/sdk/trp/client.go`](../go-sdk/sdk/trp/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/trp/client.py`](../python-sdk/sdk/src/tx3_sdk/trp/client.py) | |
| 3.2 | TRP `submit`                         | ✅ | ✅ | ✅ [`go-sdk/sdk/trp/client.go`](../go-sdk/sdk/trp/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/trp/client.py`](../python-sdk/sdk/src/tx3_sdk/trp/client.py) | |
| 3.2 | TRP `checkStatus`                    | ✅ | ✅ [`web-sdk/sdk/src/trp/client.ts`](../web-sdk/sdk/src/trp/client.ts) | ✅ [`go-sdk/sdk/trp/client.go`](../go-sdk/sdk/trp/client.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/trp/client.py`](../python-sdk/sdk/src/tx3_sdk/trp/client.py) | |
| 3.3 | `Tx3ClientBuilder` seeded from `Protocol.client()` | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/clientBuilder.ts`](../web-sdk/sdk/src/facade/clientBuilder.ts) | ✅ [`go-sdk/sdk/facade/client_builder.go`](../go-sdk/sdk/facade/client_builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client_builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/client_builder.py) | Go uses idiomatic package-level entry — `facade.FromProtocol(p)` (also re-exported as `tx3sdk.ProtocolClient(p)`) — instead of `Protocol.Client()` to avoid a `tii→facade→tii` import cycle. |
| 3.3 | `Tx3ClientBuilder.fromParts(transactions, profiles, knownParties)` | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/clientBuilder.ts`](../web-sdk/sdk/src/facade/clientBuilder.ts) | ✅ [`go-sdk/sdk/facade/client_builder.go`](../go-sdk/sdk/facade/client_builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client_builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/client_builder.py) | Seeding entry used by codegen-generated wrappers. |
| 3.3 | Mandatory `trp(opts)` / `trpEndpoint(url)` setters + `build()` with named variants (`MissingTrpEndpoint`, `UnknownProfile`, `UnknownParty`) | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/clientBuilder.ts`](../web-sdk/sdk/src/facade/clientBuilder.ts) | ✅ [`go-sdk/sdk/facade/client_builder.go`](../go-sdk/sdk/facade/client_builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client_builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/client_builder.py) | Web/Python use TS/Python-idiomatic typed exceptions; Go returns `(*Tx3Client, error)` with the named variants discriminable via `errors.As`. `UnknownProfileError` lives in `tii/errors` across all SDKs and is re-used by the builder. |
| 3.3 | `withParty` / `withParties` / `withHeader` on builder | ✅ | ✅ [`web-sdk/sdk/src/facade/clientBuilder.ts`](../web-sdk/sdk/src/facade/clientBuilder.ts) | ✅ [`go-sdk/sdk/facade/client_builder.go`](../go-sdk/sdk/facade/client_builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client_builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/client_builder.py) | Late-binding `withParty`/`withParties` also exposed on built `Tx3Client` (validated, like rust). |
| 3.3 | `withPartyUnchecked` on builder AND client | ✅ | ✅ | ✅ | ✅ | Codegen entry point everywhere. |
| 3.3 | `tx(name)` returns recoverable `UnknownTx` (no panic/throw) | ✅ | ✅ (throws facade `UnknownTxError` ← `TiiError`-rooted, `instanceof`-discriminable) | ✅ Go: `(*TxBuilder, error)` with `*tii.UnknownTxError` | ✅ Python: raises `UnknownTxError` (TII-rooted exception) at call site | All four raise at the call site, not at resolve time. |
| 3.4 | `Party.address` / `Party.signer`     | ✅ | ✅ [`web-sdk/sdk/src/facade/party.ts`](../web-sdk/sdk/src/facade/party.ts) | ✅ [`go-sdk/sdk/facade/party.go`](../go-sdk/sdk/facade/party.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/party.py`](../python-sdk/sdk/src/tx3_sdk/facade/party.py) | Go: `AddressParty()` / `SignerParty()`. |
| 3.4 | Auto-inject party addresses into args | ✅ | ✅ [`web-sdk/sdk/src/facade/builder.ts`](../web-sdk/sdk/src/facade/builder.ts) | ✅ [`go-sdk/sdk/facade/builder.go`](../go-sdk/sdk/facade/builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/builder.py) | |
| 3.5 | `Signer` interface                   | ✅ (`trait Signer`) | ✅ [`web-sdk/sdk/src/signer/signer.ts`](../web-sdk/sdk/src/signer/signer.ts) | ✅ [`go-sdk/sdk/signer/signer.go`](../go-sdk/sdk/signer/signer.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/signer/signer.py`](../python-sdk/sdk/src/tx3_sdk/signer/signer.py) | Go interface: `Address()`, `Sign()`. |
| 3.5 | `CardanoSigner` (BIP32 1852'/1815')  | ✅ | ✅ [`web-sdk/sdk/src/signer/cardano.ts`](../web-sdk/sdk/src/signer/cardano.ts) | ✅ [`go-sdk/sdk/signer/cardano.go`](../go-sdk/sdk/signer/cardano.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/signer/cardano.py`](../python-sdk/sdk/src/tx3_sdk/signer/cardano.py) | Go uses `filippo.io/edwards25519` + `golang.org/x/crypto`. |
| 3.5 | `Ed25519Signer`                      | ✅ | ✅ [`web-sdk/sdk/src/signer/ed25519.ts`](../web-sdk/sdk/src/signer/ed25519.ts) | ✅ [`go-sdk/sdk/signer/ed25519.go`](../go-sdk/sdk/signer/ed25519.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/signer/ed25519.py`](../python-sdk/sdk/src/tx3_sdk/signer/ed25519.py) | Go uses stdlib `crypto/ed25519`. |
| 3.5b | Manual witness attachment (`addWitness` on `ResolvedTx`) | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/resolved.ts`](../web-sdk/sdk/src/facade/resolved.ts) | ✅ [`go-sdk/sdk/facade/resolved.go`](../go-sdk/sdk/facade/resolved.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/resolved.py`](../python-sdk/sdk/src/tx3_sdk/facade/resolved.py) | TxWitness input only. Web-sdk also ships [`Cip30Signer`](../web-sdk/sdk/src/signer/cip30.ts) + `cip30Party()` as a sibling signer module. |
| 3.6 | `withProfile` is builder-only (NOT on built client) | ✅ | ✅ | ✅ | ✅ | All four removed `withProfile` from the built `Tx3Client`. Switching profiles requires constructing a new client through a fresh builder. |
| 3.6 | `withEnvValue` on builder            | ✅ [`rust-sdk/sdk/src/facade.rs`](../rust-sdk/sdk/src/facade.rs) | ✅ [`web-sdk/sdk/src/facade/clientBuilder.ts`](../web-sdk/sdk/src/facade/clientBuilder.ts) | ✅ [`go-sdk/sdk/facade/client_builder.go`](../go-sdk/sdk/facade/client_builder.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/client_builder.py`](../python-sdk/sdk/src/tx3_sdk/facade/client_builder.py) | Merged on top of the selected profile's environment at resolve time. |
| 3.7 | `waitForConfirmed` / `waitForFinalized` + `PollConfig` | ✅ | ✅ [`web-sdk/sdk/src/facade/submitted.ts`](../web-sdk/sdk/src/facade/submitted.ts) | ✅ [`go-sdk/sdk/facade/submitted.go`](../go-sdk/sdk/facade/submitted.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/facade/submitted.py`](../python-sdk/sdk/src/tx3_sdk/facade/submitted.py) | Defaults: 20 attempts, 5 s. Go respects `context.Context` cancellation. |
| 3.8 | Discriminated error model            | ✅ (`facade::Error` enum) | ✅ Full hierarchy via `instanceof` | ✅ Per-domain marker interfaces + `errors.As()` | ✅ Rooted at `Tx3Error` with category subclasses | Go: `TiiError`, `TrpError`, `SignerError`, `FacadeError` marker interfaces. Note: `MissingTrpEndpoint`/`UnknownProfile`/`UnknownParty` builder-error variants only exist where the builder exists (rust-sdk today). |
| 3.9 | Argument marshalling                 | ✅ (`core::ArgMap`) | ✅ [`web-sdk/sdk/src/core/args.ts`](../web-sdk/sdk/src/core/args.ts) | ✅ [`go-sdk/sdk/core/args.go`](../go-sdk/sdk/core/args.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/core/args.py`](../python-sdk/sdk/src/tx3_sdk/core/args.py) | Go: `ArgValue` tagged union + `CoerceArg()` for native types. |
| 3.9 | Complex param-type interpretation (`list`/`tuple`/`map`/`record`/`variant`) | ✅ [`rust-sdk/sdk/src/tii/mod.rs`](../rust-sdk/sdk/src/tii/mod.rs) | ✅ [`web-sdk/sdk/src/tii/paramType.ts`](../web-sdk/sdk/src/tii/paramType.ts) | ✅ [`go-sdk/sdk/tii/param_type.go`](../go-sdk/sdk/tii/param_type.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/tii/param_type.py`](../python-sdk/sdk/src/tx3_sdk/tii/param_type.py) | All four implement the canonical model in [`api-surface/args.md`](sdk-spec/api-surface/args.md): scalar core `$ref`s matched by **trailing name** across both `tii#/$defs/<Name>` and legacy `core#<Name>` forms (incl. `Utxo`/`AnyAsset`); distinct `list`(inner)/`tuple`(elements)/`map`(value)/`record`(fields)/`variant`(cases) kinds carrying their element types; `#/components/schemas/<Name>` resolved + recursed; **never throws** — unrecognized shapes (bare `string`, unresolved object, unknown `$ref`) become `unknown`/`Unknown`/`UNKNOWN` carrying the raw schema. Each SDK has a unit suite over the full table; Go added a custom `Schema` unmarshaler for the `items:false` / `additionalProperties:false` forms `tx3c` emits, and Rust dropped `schemars` for `serde_json::Value`. **Breaking** `ParamType` reshape → minor/major bumps. Shared fixture: [`sdk-spec/test-vectors/complex-types/complex.tii`](sdk-spec/test-vectors/complex-types/complex.tii). |
| 3.9 | Type-directed value validation / encoding | ✅ [`rust-sdk/sdk/src/tii/encode.rs`](../rust-sdk/sdk/src/tii/encode.rs) | ✅ [`web-sdk/sdk/src/tii/encode.ts`](../web-sdk/sdk/src/tii/encode.ts) | ✅ [`go-sdk/sdk/tii/encode.go`](../go-sdk/sdk/tii/encode.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/tii/encode.py`](../python-sdk/sdk/src/tx3_sdk/tii/encode.py) | **Implemented across all four** (sprint complex-types WU-04): each SDK marshals every arg through one recursive `(type, value)` walk wired into `into_resolve_request` (no separate scalar/complex path) — a scalar leaf renders **bare** at the top level (resolver coerces via flat type) and **tagged** when nested in an aggregate; aggregates always render to the self-describing `TaggedArg` (`api-surface/args.md` → "The `TaggedArg` contract"; schema in `core/trp/v1beta0/trp.json`; shared oracle [`test-vectors/complex-types/wire-vectors.json`](sdk-spec/test-vectors/complex-types/wire-vectors.json)). Each reshaped its record `ParamType` to preserve **declared (`required`) order, not alphabetical `properties`**; variant constructor = `oneOf` case index; map keys carried as `string` leaves (the `.tii` erases the key type), pairs sorted. Each ships the vector-driven accept/reject suite + a field-order test (`Meta { tags, level }` → `[list, int]`). The resolver mirror is symmetric: one `from_json` where a tagged value decodes by its tags and a bare value coerces via the flat type. **Breaking** `ParamType` record reshape → coordinated bump. Codegen variant-construction bindings (`tx3c` `schemaTypeFor` tuple/map/variant) remain pending. |
| §4  | Top-level re-exports                 | ✅ [`lib.rs`](../rust-sdk/sdk/src/lib.rs) | ✅ [`web-sdk/sdk/src/index.ts`](../web-sdk/sdk/src/index.ts) | ✅ [`go-sdk/sdk/tx3sdk.go`](../go-sdk/sdk/tx3sdk.go) | ✅ [`python-sdk/sdk/src/tx3_sdk/__init__.py`](../python-sdk/sdk/src/tx3_sdk/__init__.py) | All four export `Tx3Client`, `Tx3ClientBuilder`, `Party`, `CardanoSigner`/`Ed25519Signer`, `PollConfig`, plus `Profile` and `MissingTrpEndpointError`. |

---

## Codegen plugin parity

Capability references are to `sdk-spec/codegen/`. Codegen is an **optional** SDK capability; an `—` here means the SDK has not opted in and is not required to.

| # | Capability | `rust-sdk` | `web-sdk` | `go-sdk` | `python-sdk` | Notes |
|---|---|---|---|---|---|---|
| C.1 | `.trix/client-lib/` template set present | ✅ [`rust-sdk/.trix/client-lib/`](../rust-sdk/.trix/client-lib/) | ✅ [`web-sdk/.trix/client-lib/`](../web-sdk/.trix/client-lib/) | ✅ [`go-sdk/.trix/client-lib/`](../go-sdk/.trix/client-lib/) | ✅ [`python-sdk/.trix/client-lib/`](../python-sdk/.trix/client-lib/) | All four SDKs ship a plugin at the canonical convention path. |
| C.2 | Targets current TII version (`v1beta0`) | ✅ | ✅ | ✅ | ✅ | All four templates render against the `v1beta0` `tii.*` data shape via `schemaTypeFor`. |
| C.3a | Per-tx `Params` + `TIR` constant + facade method | ✅ | ✅ | ✅ | ✅ | All four emit a `Params` type, a TIR constant, and a `Client` transaction method. |
| C.3b | Protocol identity constants (name, version, target TII version) | ✅ | ✅ | ✅ | ✅ | All four emit protocol name, version, and `TARGET_TII_VERSION`. [generated-surface.md §Protocol identity](sdk-spec/codegen/generated-surface.md). |
| C.3c | Profiles + environment embedded + wired into facade | ✅ | ✅ | ✅ | ✅ | All four embed `PROFILES` + environment schema and accept a profile selector on the `Client`. [generated-surface.md §Profiles and environment](sdk-spec/codegen/generated-surface.md). |
| C.3d | Generated `Client` wraps `Tx3ClientBuilder.fromParts` (no re-implemented lifecycle) | ✅ | ✅ [`web-sdk/.trix/client-lib/protocol.ts.hbs`](../web-sdk/.trix/client-lib/protocol.ts.hbs) | ✅ [`go-sdk/.trix/client-lib/protocol.go.hbs`](../go-sdk/.trix/client-lib/protocol.go.hbs) | ✅ [`python-sdk/.trix/client-lib/__init__.py.hbs`](../python-sdk/.trix/client-lib/__init__.py.hbs) | All four generated `Client`s seed `Tx3ClientBuilder.fromParts(...)`, then route typed per-party setters through `withPartyUnchecked`. **Note:** the in-repo `codegen-check.sh` installs each SDK from its published registry (`tx3-sdk@latest` on npm, `github.com/tx3-lang/go-sdk/sdk v0.11.0` via Go modules, `tx3-sdk` on PyPI), so the rendered output will fail to compile until each SDK ships a release containing `Tx3ClientBuilder`. |
| C.4 | Plugin tag immutability + `codegen-v<TII>` naming | ✅ `codegen-v1beta0` | ✅ `codegen-v1beta0` | ✅ `codegen-v1beta0` | ✅ `codegen-v1beta0` | All four tags point at the merged v1beta0 templates. Tag policy in [codegen/plugin-layout.md](sdk-spec/codegen/plugin-layout.md). |
| C.5 | Render-fixture check ([testing.md](sdk-spec/codegen/testing.md)) | ✅ [`rust-sdk/.github/scripts/codegen-check.sh`](../rust-sdk/.github/scripts/codegen-check.sh) | ✅ [`web-sdk/.github/scripts/codegen-check.sh`](../web-sdk/.github/scripts/codegen-check.sh) | ✅ [`go-sdk/.github/scripts/codegen-check.sh`](../go-sdk/.github/scripts/codegen-check.sh) | ✅ [`python-sdk/.github/scripts/codegen-check.sh`](../python-sdk/.github/scripts/codegen-check.sh) | A CI-owned shell script run by a dedicated `codegen` job: renders the shared fixture, compiles/type-checks the output, and smoke-checks the generated surface. Not SDK test code. |

---

## Cross-cutting policy parity

| Policy capability | `rust-sdk` | `web-sdk` | `go-sdk` | `python-sdk` | Notes |
|---|---|---|---|---|---|
| Unified CI workflow policy (`testing/ci-workflows.md`) | ✅ [`rust-sdk/.github/workflows/ci.yml`](../rust-sdk/.github/workflows/ci.yml) | ✅ [`web-sdk/.github/workflows/ci.yml`](../web-sdk/.github/workflows/ci.yml) | ✅ [`go-sdk/.github/workflows/ci.yml`](../go-sdk/.github/workflows/ci.yml) | ✅ [`python-sdk/.github/workflows/ci.yml`](../python-sdk/.github/workflows/ci.yml) | Unit/e2e are selected by explicit language-idiomatic selectors (Rust e2e targets, Web `test:unit`/`test:e2e`, Go `e2e` build tag, Python `e2e` marker). |
| Release policy (`release-policy.md`) | ✅ [`rust-sdk/.github/workflows/release.yml`](../rust-sdk/.github/workflows/release.yml) | ✅ [`web-sdk/.github/workflows/release.yml`](../web-sdk/.github/workflows/release.yml) | ✅ [`go-sdk/.github/workflows/release.yml`](../go-sdk/.github/workflows/release.yml) | ✅ [`python-sdk/.github/workflows/release.yml`](../python-sdk/.github/workflows/release.yml) | Core SDK packages only. Rust/Web/Python use `vMAJOR.MINOR.PATCH`; Go uses `sdk/vMAJOR.MINOR.PATCH`. |

---

## Per-SDK summary

### `rust-sdk` (v0.12.0)

Reference implementation. All required capabilities in §3 are implemented, including the unified `Tx3ClientBuilder` (seeded via `Protocol::client()` or `Tx3ClientBuilder::from_parts`) and `with_party_unchecked` on both builder and client. The codegen plugin wraps that builder rather than re-implementing lifecycle. Main follow-ups are 1.0 polish, not parity gaps:

- Consider expanding the built-in `Signer` set (hardware wallet shims, external-signer bridge).
- Lock down the `core::ArgMap` API before 1.0.

### `web-sdk` (`tx3-sdk` v0.11.0 — merged, awaiting release)

All §3 capabilities implemented, including the §3.3 builder pattern (`Tx3ClientBuilder`, `Protocol.client()`, `fromParts`, `trp`/`trpEndpoint`/`withHeader`/`withProfile`/`withParty`/`withPartyUnchecked`/`withParties`/`withEnvValue`/`build()`) and the §3.6 builder-only `withProfile`. `Tx3Client` no longer exposes `withProfile`; `tx(name)` throws facade `UnknownTxError` at call site. New `BuilderError` family rooted under `Tx3Error` (`MissingTrpEndpointError`, `UnknownPartyError`). Codegen plugin's generated `Client` wraps `Tx3ClientBuilder.fromParts(...)`. Unit + e2e CI green; the `codegen` CI job will remain red until v0.12 publishes to npm (script installs from `latest`).

Build-time codegen integrations (`vite-plugin-tx3`, `rollup-plugin-tx3`, `next-tx3`) drive the `.trix/client-lib/` plugin from a bundler.

### `go-sdk` (`github.com/tx3-lang/go-sdk/sdk` v0.11.0 — merged, awaiting release tag)

All §3 capabilities implemented. `Tx3ClientBuilder` lives in `sdk/facade/client_builder.go`. Idiomatic Go: `facade.FromProtocol(p)` is the dynamic-flow entry (re-exported as `tx3sdk.ProtocolClient(p)`) — `Protocol.Client()` would create a `tii → facade → tii` import cycle and is not present. `Build() (*Tx3Client, error)` returns `*MissingTrpEndpointError`/`*tii.UnknownProfileError`/`*facade.UnknownPartyError`, all discriminable via `errors.As`. `Tx(name)` and `Tx3Client.WithParty()` return `(value, error)` (Go idiom for recoverable lookup). Old `facade.NewClient(protocol, trp)` constructor removed. Codegen template wraps `facade.FromParts(...)`. Unit + e2e CI green; the `codegen` CI job will remain red until a new `sdk/v0.12.0` tag is cut (rendered `go.mod` resolves the SDK by tag).

### `python-sdk` (`tx3-sdk` v0.11.0 — merged, awaiting release)

All §3 capabilities implemented. `Tx3ClientBuilder` lives in `sdk/src/tx3_sdk/facade/client_builder.py`. `Protocol.client()` returns a builder. `build()` raises `MissingTrpEndpointError`/`UnknownProfileError`/`UnknownPartyError` (all `BuilderError` subclasses under `Tx3Error`). `Tx3Client.tx(name)` raises `UnknownTxError` at call site instead of deferring to `resolve()`. `with_profile` removed from built client. `with_env_value` + `with_header` + `with_party_unchecked` all present. Unit + e2e CI green (17 builder-pattern tests + migrated coverage); the `codegen` CI job will remain red until v0.12 publishes to PyPI. The builder exposes an internal `_trp_client(client)` escape hatch used by tests to inject mock TRP clients (not part of the public API).

---

## How to update this file

1. Audit a capability by reading both the spec and the SDK source. Don't trust the existing cell.
2. Update the cell (✅/🚧/❌) and, if ✅, link the actual source file path.
3. If you found a new sub-capability worth tracking, add a row rather than overloading an existing one.
4. Bump the **Snapshot date** above.
5. If you close or open a gap, mention it in the per-SDK summary.

The `audit-parity` skill automates steps 1–4. Use it when in doubt.
