# Plan: extract TII handling into a shared `tx3-tii` crate

Status: **open / not started**
Scope: cross-cutting — new `tii/crates/tx3-tii`, plus `tx3` (tx3c,
tx3-resolver), `trix`, `registry/tracker`.
Origin: design evaluation of TII parse/build duplication across the
factory (2026-05-18).

## Context

`.tii` (Transaction Invoke Interface) handling is duplicated across the
factory monorepo, with no single source of truth and no reusable library:

- **Model duplicated 4×**: `tx3/bin/tx3c/src/tii/types.rs` (emit-side,
  binary-private — tx3c has no `lib.rs`), external `tx3-sdk::tii::spec`
  (used by `registry/tracker`), `tx3-resolver::interop::TirEnvelope`
  (published, near-identical), and trix's hand-rolled `TiiLite` mirror in
  `inspect/tir.rs`, plus untyped `serde_json::Value` parsing in
  `trix/src/interfaces/mod.rs`.
- **TII building exists only inside the `tx3c` binary**
  (`tii/mod.rs::emit_tii`), with schema-inference helpers further
  duplicated between tx3c's build and codegen sides.
- The `lang-factory/tii/` repo is **spec-only** (`v1beta0/tii.json`,
  examples) — unlike `lang-factory/tir/`, which hosts the published
  `tx3-tir` crate alongside its spec. TII lacks the reference Rust impl
  that TIR has.

Goal: one `tx3-tii` crate owning the TII model + parse/traverse + build,
reused by trix, tx3c, and registry/tracker — eliminating the duplication
and (eventually) the trix↔tx3c spawn dependency for TII.

## Recommended decisions

1. **Crate home: `tii/crates/tx3-tii`** — make `tii/` a Cargo workspace
   mirroring the `tir/` precedent. Rationale: spec/impl colocation
   (conformance test next to `v1beta0/tii.json`), independent publish
   cadence (decouples from the 0.17 monorepo train causing trix's skew),
   lowest-surprise repo→crate mapping. Trade-off: a new cross-repo
   `tx3-tii → tx3-lang` edge (mitigated below).
2. **Scope: model + parse + build** (full extraction), phased so the
   parse side (highest dedup payoff, lowest risk) lands independent of
   the build extraction from tx3c.
3. **Consolidation depth: full** — tx3-resolver re-exports from tx3-tii;
   registry/tracker drops external `tx3-sdk`. Done last so it's
   independently revertable.

## Crate `tx3-tii` (`tii/crates/tx3-tii`)

```
tii/Cargo.toml                 # NEW workspace, members=["crates/tx3-tii"], mirrors tir/Cargo.toml
tii/crates/tx3-tii/src/
  lib.rs        # re-exports; pub const TII_VERSION = "v1beta0"
  model.rs      # TiiFile,TiiInfo,Protocol,Transaction,TirEnvelope,BytesEncoding,Party,Profile,Components
  parse.rs      # from_slice/str/file; transaction_names(); transaction(); Transaction::decode_tir[_json]()
  build.rs      # build(&tx3_lang::Workspace, ProtocolMeta, &[ProfileInput]) -> TiiFile
  schema.rs     # ast→json-schema inference (from tx3c tii/mod.rs helpers)
  profile.rs    # dotfile→profile inference (from tx3c tii/mod.rs helpers)
  error.rs
tii/crates/tx3-tii/tests/
  schema_conformance.rs   # validate serialized model + builder output vs ../../v1beta0/tii.json
  fixtures.rs             # round-trip ../../examples/transfer.tii
```

- **model.rs**: verbatim from `tx3c/src/tii/types.rs`; keep
  `schemars::Schema` for env/params. On `TirEnvelope`: serialize
  `encoding`/`content`, deserialize-accept `contentType` and
  `bytecode`/`payload` aliases (wire compat with
  `tx3-resolver::interop` and trix's current `TirEnvelopeLite`).
- **parse.rs**: absorbs trix `tir_from_interface` + `discover_transactions`.
  `decode_tir` reuses `tx3_tir::encoding::{from_bytes,TirVersion,AnyTir}`
  and the resolver's `TryFrom<TirEnvelope> for AnyTir`/`From<AnyTir>`
  logic (moved here).
- **build.rs**: `emit_tii` body (tx3c `tii/mod.rs:186-271`) minus CLI/IO.
- Deps: serde, serde_json, schemars (match tx3c pin), hex, thiserror,
  tx3-tir, tx3-lang. Dev: jsonschema. **No** dep on
  trix/tx3c/resolver/sdk.
- Layering: beside tx3-tir (model/parse), above tx3-tir+tx3-lang (build);
  tx3-resolver depends on it (no cycle).

## Critical files

- `tx3/bin/tx3c/src/tii/types.rs` (deleted → `pub use tx3_tii::model::*`)
- `tx3/bin/tx3c/src/tii/mod.rs` (thin CLI shim around `tx3_tii::build`)
- `tx3/bin/tx3c/src/codegen.rs` (optional: typed deserialize; Handlebars
  JSON stays byte-identical)
- `tx3/crates/tx3-resolver/src/interop.rs` (re-export tx3-tii types)
- `trix/src/commands/inspect/tir.rs` (drop `*Lite` + `tir_from_interface`)
- `trix/src/interfaces/mod.rs` (`discover_transactions`, `verify_cached`)
- `trix/Cargo.toml` (add tx3-tii; bump tx3-lang/tx3-tir 0.14.2→0.17.x)
- `registry/tracker/src/discovery.rs` + `tracker/Cargo.toml`
  (tx3-sdk→tx3-tii)
- `tii/v1beta0/tii.json`, `tii/examples/transfer.tii` (conformance inputs)

## Phases (each independently buildable/shippable)

**Phase 1 — crate + tx3c adopts (repos: `tii` new, `tx3`).** Low risk.
1. `tii/Cargo.toml` workspace + `tii/crates/tx3-tii/**` with tests.
2. tx3c depends on tx3-tii (path dep in dev); delete `tii/types.rs`
   (`pub use tx3_tii::model::*`); `tii/mod.rs` → parse Args → build
   ProtocolMeta/ProfileInputs → `tx3_tii::build` → write + println.
3. (Optional, separable) `codegen.rs::run` typed-deserialize to
   `tx3_tii::TiiFile` then `to_value` — Handlebars input unchanged.

**Phase 2 — trix adopts parse (repo: `trix`).** Medium risk (skew).
1. **Isolated commit**: bump `trix/Cargo.toml` tx3-lang/tx3-tir
   0.14.2→0.17.x; run full trix suite (isolates skew breakage from
   tx3-tii integration).
2. Add `tx3-tii`; `inspect/tir.rs` Interface arm → `tx3_tii::from_file`
   + `decode_tir_json`; delete `*Lite`/`tir_from_interface`.
3. `interfaces/mod.rs`: `discover_transactions` →
   `tx3_tii::from_slice(..).transaction_names()`; `verify_cached` JSON
   check → typed `TiiFile` parse (stronger validation — intended
   hardening; same `CacheStatus::Invalid` mapping).
- Out of scope (note as future): replacing the `tx3c build --emit tii`
  subprocess with in-process `tx3_tii::build()`.

**Phase 3 — registry + resolver consolidation (repos: `registry`, `tx3`).**
1. tracker: drop `tx3-sdk`, add `tx3-tii`; `discovery.rs` import +
   turbofish to `tx3_tii::TiiFile`.
2. tx3-resolver: `pub use tx3_tii::model::{TirEnvelope,BytesEncoding}`,
   remove local defs + impls (keep `BytesEnvelope`, a distinct type).

## Version-skew handling (the main risk)

trix pins tx3-lang/tx3-tir 0.14.2; tx3-tii builds against 0.17.x. Mixed
graph → two incompatible `AnyTir`/`Workspace` copies → compile errors at
the `decode_tir` boundary. Mitigation: Phase 2 step 1 is a standalone
reviewable bump commit *before* tx3-tii is added (the commented path/git
lines in `trix/Cargo.toml` show this bump dance is already standard).
tx3-tii, tx3c, tracker, trix must agree on one tx3-lang/tx3-tir minor;
tx3-tii declares it at the 0.17.x line tx3c/tracker already use. Phase
1/3 repos are already 0.17.x — no skew work there.

## Verification (end-to-end, per submodule)

- **tx3-tii**: `cargo test -p tx3-tii` — parse/decode/build units;
  `schema_conformance.rs` validates serialized model + builder output
  vs `tii/v1beta0/tii.json`; round-trip `tii/examples/transfer.tii`.
- **tx3c (P1)**: `tx3c build --emit tii` on an example `.tx3`,
  **byte-diff the `.tii` vs pre-refactor output** (must be identical);
  `tx3c codegen` rust/ts/py/go, diff generated output (must be identical
  → proves typed round-trip preserved Handlebars input).
- **trix (P2)**: existing e2e `use_command` + `codegen_deps`;
  `inspect tir` project vs interface path produce identical IR JSON. Run
  full suite once on the bumped-deps commit *before* adding tx3-tii.
- **registry (P3)**: parse-equivalence test — same real published `.tii`
  parsed by `tx3_sdk::tii::spec::TiiFile` and `tx3_tii::TiiFile` yields
  the same protocols/txs *before* deleting the tx3-sdk dep.

## Risks / decision points

- **R1 skew**: trix 0.14→0.17 may surface unrelated API drift — isolated
  bump commit gates Phase 2.
- **R2 resolver wire-compat**: must preserve `bytecode`/`payload`/
  `contentType` serde aliases; assert via serde round-trip test.
- **R3 new cross-repo edge**: `tx3-tii → tx3-lang`; `tii` repo needs a
  publishable/git-pinnable tx3-lang 0.17.x (path in dev, version/git for
  release) — confirm before declaring the dep.
- **R4 stricter verify_cached**: typed parse rejects malformed-but-JSON
  caches that previously passed (intended); confirm no trix fixture
  relies on the old leniency.
- **R5 tx3-sdk parity**: external `tx3-sdk` `TiiFile` shape vs canonical
  schema — Phase 3 parity test before removing the dep.
- **R6 codegen typed round-trip**: `schemars::Schema` must serialize
  byte-identically; byte-diff gate in tx3c verification; if any diff,
  keep codegen on untyped `Value` (its refactor is optional).

## Decision log

- _(unset)_ Crate home → recommended **`tii/crates/tx3-tii`**.
- _(unset)_ Scope → recommended **model + parse + build**.
- _(unset)_ Consolidation depth → recommended **full (incl. Phase 3)**.
