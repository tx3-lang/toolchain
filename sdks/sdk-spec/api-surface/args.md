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

Argument **values** are marshalled to the TRP wire format independently of the parameter-type model (the wire form is a plain JSON value; the TRP resolver performs authoritative type checking). Marshalling MUST be **generic-recursive**: scalar coercions (byte arrays → `0x`-prefixed hex, big integers → their wire encoding) MUST be applied to values nested inside lists, tuples, maps, and records, not only to top-level args. The wire value for a `list`/`tuple` is a JSON array; for a `map`/`record`/`variant` it is a JSON object.

> Type-*directed* validation/encoding (using the resolved `ParamType` to validate each arg) and the variant-construction encoder are not yet required; track them in `parity-matrix.md` when added.

*Rust reference:* `tx3_sdk::core::ArgMap`, `tx3_sdk::tii::ParamType`. *Web reference:* `web-sdk/sdk/src/core/args.ts`, `web-sdk/sdk/src/tii/paramType.ts`.
