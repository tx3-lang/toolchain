# Plan: complex argument-type support through `trix invoke` / TRP resolve

Status: **open / not started.**
Scope: cross-cutting — `core/tir` (value model + reduction), `lang/tx3`
(`crates/tx3-resolver`), the **dolos** release that embeds the resolver, and the
toolchain manifests. Pairs with the SDK-side encoder tracked in
[`sdk-complex-type-followups.md`](./sdk-complex-type-followups.md) (§1/§2).
Related: [`tx3-protocol-limitations.md`](./tx3-protocol-limitations.md),
[`dx-e2e-journey-roadmap.md`](./dx-e2e-journey-roadmap.md) (the `05-invoke` journey).

## Context

A consumer can declare a transaction parameter of a complex type — a record
(custom type), `List`, `Map`, `Tuple` — and `trix invoke` cannot bind a value to
it. Resolution fails with:

```
❗️ error: target type not supported: Custom("Meta")   (JSON-RPC -32005)
```

This is the capability the `05-invoke` DX e2e journey asserts (its fixture passes
a record nesting a `List<Int>`), which is why that journey is intentionally red.

### Where the support actually breaks (verified layer-by-layer)

The arg flows: SDK reads the TII param types → sends args as JSON over TRP →
the resolver coerces each JSON arg to the param's type → reduction substitutes it
into the transaction template.

| Layer | Component | State |
|---|---|---|
| TII-load type recognition | `tx3-sdk::tii::from_json_schema` | ✅ reads list/tuple/map/record/variant (tx3-sdk 0.13.0) |
| SDK arg value encoding | per-SDK `ArgValue`/`fromJson` | ⚠️ generic recursive JSON pass-through; no type-directed encoding — see [`sdk-complex-type-followups.md`](./sdk-complex-type-followups.md) §1/§2 |
| **TRP arg coercion** | `tx3-resolver::interop::from_json` (`lang/tx3/crates/tx3-resolver/src/interop.rs:265`) | ❌ matches only `Int/Bool/Bytes/Address/UtxoRef/Undefined`; everything else → `Error::TargetTypeNotSupported` |
| **Resolver value model** | `ArgValue` (`core/tir/crates/tx3-tir/src/reduce/mod.rs:1514`) | ❌ scalar-only: `Int/Bool/String/Bytes/Address/UtxoRef/UtxoSet` — no variant can hold a record/list/map/tuple |
| Arg → template substitution | `arg_value_into_expr` (`core/tir/.../reduce/mod.rs:393`) | ❌ maps only the scalar `ArgValue`s to `Expression` |
| TIR target representation | `Expression` (`core/tir/.../model/v1beta0.rs:187`) | ✅ already has `List`, `Map`, `Tuple`, `Struct(StructExpr)` |
| Running TRP | **dolos** devnet | ❌ pins published `tx3-resolver 0.21.0`; a merged fix reaches `trix invoke` only after a dolos release + manifest bump |

The SDK layer is done; the wall is the **resolver + the value model** beneath it.
Note the architectural assumption recorded in `sdk-complex-type-followups.md`:
the SDKs deliberately pass complex values as generic JSON because "the TRP
resolver performs authoritative type checking." The resolver does not yet hold up
that contract — closing it here is what makes that assumption true.

## The central design question (records/variants)

`Expression` already models the targets, so the mechanical cases are
straightforward — a JSON array → `Expression::List`/`Tuple`, a JSON object →
`Expression::Map` — none need a type definition; the structure is in the JSON.

Records and variants are the hard case. `StructExpr { constructor: usize, fields:
Vec<Expression> }` is **positional** (a Plutus-data constr), but a JSON record arg
is **by-name and unordered**, and `Type::Custom("Meta")` carries only the type
*name* — the reduced `Tx` TIR (`core/tir/.../model/v1beta0.rs:342`) holds **no
custom-type registry** to recover the constructor index and field order from.
So something must supply that mapping. Candidate approaches (decide before coding):

- **(A) Type-directed encoding in the SDK** — the SDK has the full `ParamType`
  (record field order via the schema `properties` / component), so it lowers a
  by-name record value into a positional/constr wire form; the resolver then only
  builds `StructExpr`/`List`/etc. from an already-positional payload. This is the
  value-side counterpart of `sdk-complex-type-followups.md` §1/§2 and keeps the
  resolver schemaless. **Recommended** — it matches the existing layering and the
  SDKs are where the schema already lives.
- **(B) Carry type definitions into resolution** — embed custom-type defs
  (constructor + ordered field types) in the TIR or the resolve request so the
  resolver maps by-name JSON → positional `StructExpr` itself. Heavier: changes the
  TIR/resolve wire shape and the compiler emission.

Either way, `List`/`Tuple`/`Map`/`Bytes`-nested coercion is recursive and shared.

## Workstreams

### 1. `core/tir` — value model + reduction
Add structured variants to `ArgValue` (record/list/map/tuple, mirroring the
existing `Expression` shapes) and extend `arg_value_into_expr` to build
`Expression::Struct`/`List`/`Map`/`Tuple` from them. Cover the new variants in the
`reduce` `apply_args` paths and tests. Under approach (A), the record variant
carries already-ordered positional fields.

### 2. `lang/tx3` `tx3-resolver::interop::from_json` — recursive coercion
Replace the catch-all `TargetTypeNotSupported` for the complex `Type`s with
recursive coercion into the new `ArgValue`s: arrays → `List`/`Tuple` (per
`Type`), objects → `Map`/record. Resolve the record/variant ordering per the
chosen approach (A: consume the SDK's positional form; B: look up the type def).
Add tests beside the existing `from_json_*` cases (`interop.rs` test module),
including a nested record-with-`List` matching the `05-invoke` fixture.

### 3. SDK-side encoder (only under approach A)
Implement `sdk-complex-type-followups.md` §1 (type-directed value
validation/encoding) and §2 (variant constructor) so each SDK lowers complex args
to the positional wire form the resolver expects. Sequence with that plan.

### 4. Release chain
tx3-tir → tx3-resolver (`lang/tx3`) → **dolos** (bump its `tx3-resolver` pin) →
dolos release → `manifest-beta.json` (dolos pin) → `05-invoke` greens on beta.
Per `AGENTS.md` dependency order; use the per-grouping release skills and
`channel-version-update`. This is a language/runtime feature — route via
`skills/add-language-feature/`.

## Verification

- `core/tir`: unit tests for each new `ArgValue` → `Expression` mapping and
  `apply_args` substitution.
- `tx3-resolver`: `from_json` accept tests for `List`/`Tuple`/`Map`/record,
  including the nested `record { …, List<Int> }` shape from the `05-invoke` fixture.
- End-to-end: once dolos ships, `./e2e/run.sh --channel beta --journey 05-invoke`
  resolves to a `cbor` and the journey goes green (its strict assertion is the
  acceptance check); then it can graduate from the beta matrix toward stable as the
  channels carry the fix.
- If approach A: the SDK accept/reject + variant round-trip tests from
  `sdk-complex-type-followups.md` §1/§2.
