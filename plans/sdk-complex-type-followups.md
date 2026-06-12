# Plan: SDK complex-type model — deferred follow-ups

Status: **open / not started** — depends on the complex-type model PRs landing first
Scope: cross-cutting — the four SDK submodules
(`sdks/{rust,go,python,web}-sdk`), `lang/tx3` codegen
(`bin/tx3c/src/codegen.rs` + each SDK's `.trix/client-lib/` templates), and the
shared spec/fixtures (`sdks/sdk-spec/`).
Origin: explicitly-scoped-out items from the complex param-type model rework
(2026-06-12). Shipped PRs: toolchain#11 (spec + parity + fixture),
rust-sdk#41, go-sdk#14, python-sdk#18, web-sdk#34.
Related: [`sdk-codegen-v1beta0-migration.md`](./sdk-codegen-v1beta0-migration.md)
and [`codegen-client-lifecycle-facade.md`](./codegen-client-lifecycle-facade.md)
— same `.trix/client-lib/` templates and `schemaTypeFor` helper; sequence the
codegen workstream (§3) with those.

## Context

The merged work brought every SDK's **runtime `ParamType` interpretation** to
parity with the canonical TII schema model (`sdks/sdk-spec/api-surface/args.md`):
all four now read list/tuple/map/record/variant/unit/utxo/anyAsset, match core
`$ref`s by trailing name across both URL forms, resolve
`#/components/schemas/<Name>`, and never throw (unrecognized → `unknown`).

That work deliberately stopped at **interpretation**. Three capabilities were
left out, plus one verification-hardening item. They are tracked in
`sdks/parity-matrix.md` (the "Type-directed value validation / encoding" row is
❌×4 with a note) and collected here so they aren't lost.

None of this is required for correct resolution today: argument **values** are a
generic-recursive JSON pass-through (byte arrays → `0x`-hex, big integers → wire
encoding, applied recursively into nested lists/maps/records), and the TRP
resolver performs authoritative type checking. These follow-ups improve
client-side ergonomics, type-safety, and feedback — they do not fix a
correctness bug.

## Workstreams

### 1. Type-directed value validation / encoding

Today the resolved `ParamType` is built and exposed (`Invocation::params`,
`inv.Params()`, etc.) but **not** used to validate or encode the args a caller
supplies. A user can pass a structurally-wrong value and only learn of it from a
TRP error.

The goal: drive arg coercion/validation from the resolved `ParamType` so the SDK
can (a) reject a value whose shape can't match the declared param before sending,
and (b) apply kind-specific encoding (e.g. coerce a tuple's positional elements
by their declared types rather than relying on the runtime value's JS/Go/Python
type).

- **web-sdk** is the clearest gap: `core/args.ts` has an `ArgValue` tagged union
  and a `fromJson(value, ParamTypeTag)` dispatcher whose `ParamTypeTag` enum has
  **no** list/tuple/map/record/variant tags — complex values are currently passed
  raw. Extend the tag set and the `fromJson`/`toJson` dispatch to recurse over the
  full `ParamType`.
- **rust/go/python**: thread the resolved `ParamType` into the arg setters
  (`with_arg`/`SetArg`/`arg`) or a dedicated `validate()` pass; coerce per-kind.
- Keep the generic-recursive path as the fallback for `unknown` params.

Spec: promote the "type-directed validation/encoding" note in `args.md` from
"not yet required" to a defined MUST/SHOULD once the shape is agreed. Update the
parity-matrix row.

### 2. Variant argument *construction* encoder

Interpretation models a `variant` (its cases and field types), but no SDK can yet
help a user **construct** a tagged-union value to pass as an arg. `tx3c` codegen
emits a placeholder for this (`TODO: tagged-union codegen pending the variant arg
encoder`).

The goal: an idiomatic constructor per SDK for externally-tagged variant values
(e.g. `Side.sell({ price })` → `{ "Sell": { "price": … } }`), validated against
the resolved `variant` `ParamType`. This is the value-side counterpart to §1 and
should land with it. It also unblocks the codegen TODO in §3.

### 3. Codegen typed bindings for tuple / map / variant

`lang/tx3` `bin/tx3c/src/codegen.rs` `schemaTypeFor` (and the per-SDK
`.trix/client-lib/*.hbs` templates that call it) currently map only:
- `array` + `items` → `List<T>` / `list[T]` / `[]T`
- `object` + `additionalProperties` → `Record<string,V>` / `dict[str,V]` / `map[string]V`

It does **not** handle `array` + `prefixItems` (tuple → emits a loose list/`Any`)
or `oneOf` (variant → emits `unknown`/`Any` + the TODO). So generated typed
clients lose tuple positional types and can't express variants.

The goal: extend `schemaTypeFor` to emit:
- tuples as the language's tuple/fixed-arity type (TS `[A, B]`, Python
  `tuple[A, B]`, Go a generated positional struct or `[]any` with a doc note,
  Rust a tuple),
- variants as the generated tagged-union type (pairs with §2's constructor),
- records as the already-generated component types (verify nested refs resolve).

This lives in the **lang/tx3 repo**, not the SDKs (codegen is delegated there),
but the `.hbs` templates that consume the output live in each SDK repo — change
them in lockstep. Sequence with `sdk-codegen-v1beta0-migration.md`.

### 4. Adopt the shared fixture in each SDK's unit suite

`sdks/sdk-spec/test-vectors/complex-types/complex.tii` declares one param of every
kind and was cross-checked through the python and go loaders during the rework,
but only as ad-hoc verification. Each SDK should copy/symlink the fixture into its
local fixtures and add a permanent "loads the shared complex-types vector and
resolves the expected `ParamType` kinds" test, so cross-SDK parity on one
canonical input is enforced by CI rather than asserted once. (The per-SDK unit
suites already cover the canonical *table*; this adds the composed end-to-end
load.)

## Sequencing

1. Land the five open PRs (toolchain#11 + the four SDK PRs); bump submodule
   pointers via `commit-umbrella`; cut the coordinated SDK version bump
   (`release-synced`) for the breaking `ParamType` reshape.
2. §4 (fixture adoption) — cheap, independent, do anytime after merge.
3. §1 + §2 together (value validation + variant constructor) — spec the shape in
   `args.md` first, then fan out across SDKs via `add-sdk-feature` / `propagate-change`.
4. §3 (codegen) — after §1/§2 define the runtime types the templates render against;
   coordinate with the other codegen plans.

## Verification

- §1/§2: per-SDK unit tests for accept/reject of well- and ill-shaped values
  against each kind; round-trip a variant value through construct → wire → TRP.
- §3: extend `codegen-check.sh` to render a protocol with tuple/map/variant params
  and compile the generated client in each language.
- §4: the shared-fixture load test green in all four CIs.
- `parity-matrix.md` updated as each row flips; only mark ✅ where covered by tests.
