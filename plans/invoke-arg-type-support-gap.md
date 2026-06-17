# Bug: `trix invoke` only binds `Int` / `Bool` / `Address` args — everything else fails

Status: **tracked, not yet fixed.** Reproduces on `stable` (trix 0.25.1) and the default/`beta`
channel (trix 0.26.0). Surfaced by the `05-invoke` DX e2e journey, which invokes a tx with a
diverse arg spread and strictly asserts it resolves — so it's **intentionally red** on released
channels (parked on the `beta` CI job, like `04-devnet-roundtrip`) until the gap below closes.

## Symptom

`trix check` passes and `trix build` produces a valid TII, but `trix invoke` (and `cshell tx
invoke` underneath) fails the moment any non-`Int`/`Bool`/`Address` argument is supplied via
`--args-json` / `--args-json-path`:

```
❗️ error: invalid param type
```

Verified failing arg types: `Bytes`, and the complex types `record` (custom type), `List<_>`,
`Map<_,_>`, `Tuple<_>`, and `AnyAsset`. `UtxoRef` goes through the same path and is expected to
fail too (it additionally needs pre-existing on-chain state to resolve).

## Root cause

The error is `tx3_sdk::tii::Error::InvalidParamType`, returned from `ParamType::from_json_schema`
at protocol-load time (`Protocol::from_file`, before any network call). That function is narrow —
it only recognizes three core-type `$ref`s plus scalar instance types, and errors on everything
else:

```rust
pub fn from_json_schema(schema: Schema) -> Result<ParamType, Error> {
    let as_object = schema.into_object();
    if let Some(reference) = &as_object.reference {
        return match reference.as_str() {
            "https://tx3.land/specs/v1beta0/core#Bytes"   => Ok(ParamType::Bytes),
            "https://tx3.land/specs/v1beta0/core#Address" => Ok(ParamType::Address),
            "https://tx3.land/specs/v1beta0/core#UtxoRef" => Ok(ParamType::UtxoRef),
            _ => Err(Error::InvalidParamType),
        };
    }
    if let Some(inner) = as_object.instance_type {
        return match inner {
            SingleOrVec::Single(x) => Self::from_json_type(*x), // only Integer / Boolean
            SingleOrVec::Vec(_)    => Err(Error::InvalidParamType),
        };
    }
    Err(Error::InvalidParamType)
}
```

This yields **two distinct failure modes**, both surfacing as the same `invalid param type`:

1. **`Bytes` / `UtxoRef` — `$ref` mismatch (a typo-class bug).** tx3c emits the param schema as
   `"$ref": "https://tx3.land/specs/v1beta0/tii#/$defs/Bytes"`, but the matcher above keys on
   `…/v1beta0/core#Bytes`. `…/tii#/$defs/Bytes` ≠ `…/core#Bytes`, so it falls through.

2. **Complex types — unimplemented.** A record param emits `"$ref": "#/components/schemas/Meta"`;
   a `List<_>` emits an `array`/`Vec` instance type. `from_json_schema` has no branch for local
   `#/components/schemas/…` (or `#/$defs/…`) references, no array/`List` handling, and no object
   handling — so records, lists, maps, tuples and `AnyAsset` all hit a catch-all `InvalidParamType`.

Why `Int`/`Bool`/`Address` survive: `Int`→`{"type":"integer"}` and `Bool`→`{"type":"boolean"}` are
matched by instance type; `Address` works *as an argument* only because parties are injected as
`ParamType::Address` directly (`tii/mod.rs`, `out.params.insert(party.to_lowercase(),
ParamType::Address)`), never routed through `from_json_schema`. A non-party `Address` param would
hit the same wall.

## Secondary bug: `trix invoke` exits 0 on a resolve error

Independently of the above, `trix invoke` prints `❗️ error: invalid param type` and then **exits
`0`**. A failed resolve should be a non-zero exit. This shapes the `05-invoke` journey: because the
invoke exits 0, the runner's `run_cmd` doesn't abort, so the strict `"cbor"` assertion is what turns
the journey red (and it's why the exit-code-based `xfail_cmd` helper can't be used here — it would
misread the zero exit as success). Worth fixing alongside the type support so resolve failures are
detectable by exit code.

## Fix options (for whoever picks this up)

- **`Bytes` / `UtxoRef`:** align the URIs — either tx3c emits `…/core#Bytes`, or `from_json_schema`
  also accepts `…/tii#/$defs/<T>` (accept both during the transition).
- **Complex types:** teach `from_json_schema` to resolve local component/`$defs` refs into
  `ParamType::Custom(Schema)`, handle `array` → `ParamType::List`, and cover map/tuple/`AnyAsset`.
- **Exit code:** return non-zero from `trix invoke` (and `cshell tx invoke`) on a resolve error.

Whichever side moves, bump the toolchain so a released channel carries the fix.

## Verification when fixed

The `05-invoke` journey auto-detects the fix: its diverse-typed invoke starts resolving to a
`cbor`, the strict assertion passes, and the journey goes green — at which point move it from the
`beta` CI matrix onto `stable` and delete this note. The fine-grained per-type matrix (one case per
`Bytes`/`UtxoRef`/record/`List`/`Map`/`Tuple`/`AnyAsset`) is better covered by trix's own unit
tests than by the e2e journey, which only needs the one end-to-end resolve.
