# Complex-argument follow-ups: variant construction + map key-type fidelity

Status: **open**. Follow-ons from the (shipped) complex-argument sprint, which
delivered client-side `TaggedArg` encoding end to end — aggregate args
(record/`List`/`Tuple`/`Map`) and variant *values* resolve, `05-invoke` is green
on beta. The wire form, resolver decoder, and SDK value-encoders are done; these
two gaps remain. They are independent of each other.

Reference: `TaggedArg` schema in `core/trp/v1beta0/trp.json`; SDK contract in
`sdks/sdk-spec/api-surface/args.md`; shared oracle
`sdks/sdk-spec/test-vectors/complex-types/wire-vectors.json`.

---

## A — Variant-construction codegen bindings

**What works already.** The wire form carries a `struct { constructor, fields }`
with the case index, the resolver decodes it, and every SDK encoder already turns
an externally-tagged variant *value* (`{ "Case": <payload> }`) into the right
`struct` (case index from the `.tii` `oneOf` order). So a user who hand-builds the
JSON arg can already pass a variant.

**The gap — ergonomic typed construction in generated bindings.** `tx3c` codegen
does not emit proper typed bindings for `tuple` / `map` / `variant` params: the
generated per-tx `Params` types fall back to a placeholder (the codegen still
emits a `TODO: tagged-union codegen pending the variant arg encoder`-style stub),
so a codegen consumer has no type-safe way to *construct* a variant (or tuple/map)
argument. Tracked in `parity-matrix.md` row 3.9.

**Scope.**
- `lang/tx3` codegen `schemaTypeFor` (the schema-shape → native-type mapper used by
  the `.trix/client-lib/` templates): map `tuple` (prefixItems), `map`
  (additionalProperties), and `variant` (`oneOf`) schema shapes to native types,
  replacing the placeholder. This is the cross-cutting piece — it feeds all four
  SDK templates.
- Per-SDK variant-construction helpers (sdk §2): a typed, ergonomic way to build a
  case value (e.g. `Side::sell(price)` / `Side.Sell({price})`) that the generated
  `Params` type accepts. The runtime encoder already handles the resulting value;
  this is purely the construction surface.
- Codegen render-fixture (`codegen-check.sh`) coverage: a fixture with a
  tuple/map/variant param renders + type-checks across rust/web/go/python.

**Acceptance.** Generated bindings expose typed construction for tuple/map/variant
params; the codegen render-fixture compiles in all four SDKs; `parity-matrix.md`
row 3.9 codegen note cleared.

**Order.** `lang/tx3` `schemaTypeFor` first (templates depend on it), then the
per-SDK helpers (fan out via `sdks/skills/add-sdk-feature` / `propagate-change`),
then a synced SDK release if the generated surface changes.

---

## B — Map key-type fidelity (TII layer)

**The gap.** `tx3c` lowers `Map<K, V>` to `{ "type": "object",
"additionalProperties": <V> }`, which **erases the key type `K`** (JSON object
keys are strings). So every SDK's `ParamType::Map` carries only the value type,
and the encoders fall back to emitting map keys as untyped `{ "string": k }`
leaves. For a `Map<Int, _>` / `Map<Bytes, _>`, the on-chain key is then a text
string rather than the declared type — a latent correctness gap (it doesn't break
resolution today, but the datum is semantically wrong for typed keys).

**This is a TII-layer fix, not a wire-form change.** The wire form already supports
typed map keys (the `map` body is `[[TaggedArg, TaggedArg], …]` — keys are full
`TaggedArg`s). What's missing is the key *type* reaching the SDK.

**Scope (dependency-ordered).**
1. `core/tii` + `tx3c` — emit the key type in the TII `Map` schema. Candidate:
   JSON Schema `propertyNames` (`{ "object", "propertyNames": <K-ref>,
   "additionalProperties": <V> }`), or a `tx3c` annotation. Decide the encoding in
   the TII spec (`core/tii/v1beta0/tii.json`) first.
2. SDK `ParamType::Map` — carry the key type (today value-only): each SDK's
   param-type interpreter reads the new key schema; back-compat — a `Map` schema
   without the key annotation keeps the string-leaf behaviour.
3. SDK encoders — when the key type is known, encode each map key via that type
   (its proper leaf tag) instead of `{ "string": k }`; keep the string fallback
   when absent.
4. Tests — extend `wire-vectors.json` with a typed-key map (`Map<Int, Int>` →
   `[[{ "int": 1 }, { "int": 100 }], …]`); add per-SDK encoder cases; the resolver
   already decodes typed keys (no change), but add a decode vector for symmetry.

**Acceptance.** A `Map<Int, _>` / `Map<Bytes, _>` param encodes keys with the
correct leaf tag (not `string`); round-trips through the resolver; back-compat
preserved for un-annotated map schemas; `parity-matrix.md` updated.

**Note.** Dependency direction is the usual `core/tii` → `tx3c` (in `lang/tx3`) →
SDKs; a `tx3c` release is required before SDKs can rely on the new emission, so
the string-leaf fallback must stay until the toolchain floor moves.
