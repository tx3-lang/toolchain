# &sect;3.9 &mdash; Argument Marshalling

An SDK MUST accept native host-language values for transaction args (integers, strings, booleans, byte arrays, addresses) and marshal them into the TRP wire format. Argument names MUST be matched case-insensitively against the protocol's declared params.

The SDK SHOULD expose an `ArgValue`-equivalent type for users who need to construct tagged values explicitly (useful for `UtxoRef`, `UtxoSet`, etc.).

## The parameter-type model

Each SDK builds a **parameter-type model** (`ParamType`) by interpreting each property of a transaction's `params` JSON schema (and the protocol `environment` schema). This model drives introspection (`unspecifiedParams`) and — where implemented — value coercion. `tx3c` lowers every Tx3 type into one of a fixed, closed set of schema shapes; an SDK MUST interpret all of them.

### Scalar (`$ref`) types

Built-in scalar types are emitted as a JSON `$ref`. The **canonical** form is `https://tx3.land/specs/v1beta0/tii#/$defs/<Name>`; the **legacy** form `https://tx3.land/specs/v1beta0/core#<Name>` MUST also resolve. An SDK MUST match the type by the **trailing name** — the segment after the last `#` or `/` — so both forms map identically. Matching the full URI is non-conforming (it breaks against current `tx3c` output, which emits the `tii#/$defs/` form).

| Trailing name | `ParamType` kind |
|---|---|
| `Bytes` | `bytes` |
| `Address` | `address` |
| `UtxoRef` | `utxoRef` |
| `Utxo` | `utxo` |
| `AnyAsset` | `anyAsset` |

A `$ref` of the form `#/components/schemas/<Name>` references a user-defined type; the SDK MUST resolve `<Name>` against the TII's `components.schemas` table and interpret the resolved schema recursively. The `components` table MUST therefore be threaded into the parameter-type builder.

### Primitive types

| Schema | `ParamType` kind |
|---|---|
| `{ "type": "integer" }` | `integer` |
| `{ "type": "boolean" }` | `boolean` |
| `{ "type": "null" }` | `unit` |

### Compound types

| Schema | `ParamType` kind | Carries |
|---|---|---|
| `{ "type": "array", "items": <T> }` | `list` | inner element type |
| `{ "type": "array", "prefixItems": [<T0>, <T1>, …], "items": false }` | `tuple` | positional element types |
| `{ "type": "object", "additionalProperties": <V> }` | `map` | value type (keys are always strings) |
| `{ "type": "object", "properties": {…}, "required": […] }` | `record` | field name → type |
| `{ "oneOf": [<case>, …] }` (externally tagged) | `variant` | case tag → fields |

A variant case has the externally-tagged shape `{ "type": "object", "additionalProperties": false, "required": ["<Tag>"], "properties": { "<Tag>": <fields schema> } }`. The SDK reads the single `required` entry as the case tag and interprets `properties[<Tag>]` (a record) as its fields.

An SDK SHOULD model `list` / `tuple` / `map` / `record` / `variant` as **distinct** kinds carrying their element/field types, so downstream consumers can introspect structure. An SDK that does not yet carry the inner types for a kind MUST still accept and marshal values of that kind, and MUST log the gap in `parity-matrix.md`.

### Never throw; the `unknown` fallback

Building the parameter-type model MUST NOT fail on an unrecognized schema shape (including a bare `{ "type": "string" }`, an unresolved `{ "type": "object" }` fallback that `tx3c` emits for unresolvable forward references, or an unknown `$ref`). Such shapes MUST map to an `unknown` kind that carries the raw schema. A bare `string` MUST NOT be assumed to be an `address` — `tx3c` always emits `Address` as a `$ref`, so a bare string is genuinely untyped.

## Value marshalling

Argument **values** are marshalled to the TRP wire format by a single recursive walk over the parameter's resolved `ParamType` — scalars are simply the leaf cases. A **scalar leaf** renders **bare** at the top level (a plain JSON value — byte arrays → `0x`-prefixed hex, big integers → their wire encoding — that the resolver coerces via the param's flat TIR type) and **tagged** when it sits inside an aggregate (where the resolver has no element type). An **aggregate** (`list`, `tuple`, `map`, `record`, `variant`) always renders to the self-describing `TaggedArg` structural form, recursing into its elements. There is no separate "scalar path" and "complex path": one walk, where the only distinction is whether a leaf is top-level (bare) or nested (tagged).

### The `TaggedArg` contract

The SDK is **authoritative** here: it walks the resolved `ParamType` (record field order, variant case index, list/tuple/map element types — all interpreted from the `.tii`) alongside the user value and emits a single-key tagged, recursive `TaggedArg` (canonical schema: `TaggedArg` in `core/trp/v1beta0/trp.json`):

```
TaggedArg :=
  | { "int":     <number | decimal-string | 0x-hex> }   // reuse the scalar int encoding
  | { "bool":    <bool> }
  | { "string":  <string> }                              // untyped string leaf (map keys)
  | { "bytes":   <hex string | BytesEnvelope> }          // reuse the scalar bytes encoding
  | { "address": <bech32 | hex> }
  | { "utxoRef": "<txid#index>" }
  | { "list":    [ TaggedArg, ... ] }
  | { "tuple":   [ TaggedArg, ... ] }
  | { "map":     [ [TaggedArg, TaggedArg], ... ] }      // array-of-pairs (keys may be non-string)
  | { "struct":  { "constructor": <usize>, "fields": [ TaggedArg, ... ] } }
```

Normative rules:

- **Every node inside an aggregate value MUST be tagged.** The resolver has no element/field types; tags + struct field order are the only structure it sees. A top-level scalar arg MAY be sent bare (back-compat) or tagged.
- A **record** encodes to `{ "struct": { "constructor": 0, "fields": [<fields in declared order>] } }`. The SDK maps the user's by-name object to **positional** fields ordered by the schema's `required` array — `tx3c` emits `required` in source-declaration order, whereas `properties` is alphabetized, so the field order MUST come from `required`, not from iterating `properties`.
- A **variant** resolves the user's case to its index and encodes as that case's `struct` with `constructor` = the case index in the `.tii` `oneOf` ordering.
- **Leaf scalar values reuse each SDK's existing scalar wire serializer**, wrapped in the leaf tag (`int`/`bool`/`bytes`/`address`/`utxoRef`).
- The SDK SHOULD **reject before sending** any value whose shape can't match the declared `ParamType` (missing/extra record field, wrong tuple arity, unknown variant case).
- A param the SDK can't type-direct (`unknown`, `utxo`, `anyAsset`) has no element types, so its value passes through the walk unchanged.

Shared oracle: `sdk-spec/test-vectors/complex-types/wire-vectors.json` pins, per kind, the `.tii`-typed input value → its `TaggedArg`. Both the resolver decoder and every SDK encoder MUST agree with it.

*Rust reference:* `tx3_sdk::core::ArgMap`, `tx3_sdk::tii::ParamType`, `tx3_sdk::tii::encode` (type-directed encoder). *Web reference:* `web-sdk/sdk/src/core/args.ts`, `web-sdk/sdk/src/tii/paramType.ts`.
