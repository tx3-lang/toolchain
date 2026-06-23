# Test Vectors

This directory contains canonical, spec-level e2e vectors shared across all Tx3 SDKs.

## Conventions

- Each vector lives in its own subdirectory.
- A vector MAY include:
  - a source `.tx3` file (human-readable intent),
  - a compiled `.tii` file (SDK runtime fixture),
  - profile-specific `.env` examples used by e2e tests.
- SDKs MAY copy or symlink vectors into local fixture paths, but spec references MUST target files in this directory.

## Available vectors

- `transfer/`
  - `transfer.tx3`
  - `transfer.tii`
  - `transfer.preprod.env`
- `complex-types/`
  - `complex.tii` — schema-only fixture whose `complex` transaction declares one
    param of every `ParamType` kind (integer, boolean, unit, Address, UtxoRef,
    AnyAsset, list, tuple, map, plus a component-ref record `AssetClass` and a
    component-ref variant `Side`), with scalar `$ref`s in the canonical
    `tii#/$defs/` form. Used to verify parameter-type interpretation parity
    across SDKs (see `api-surface/args.md`). The TIR envelope is a non-resolvable
    placeholder — this vector is for type-model tests, not TRP resolution.
  - `wire-vectors.json` — the shared oracle for the argument **wire encoding**
    (`TaggedArg`; see `api-surface/args.md` and the `TaggedArg` schema in
    `core/trp/v1beta0/trp.json`). Each `accept` case pins a typed parameter's
    `schema` + flat TIR `type` + native `value` → its `tagged` wire form (incl.
    the journey-critical 05-invoke `Meta{ tags: List<Int>, level: Int }` nested
    record); `reject` cases are values an SDK encoder must refuse. Both the
    resolver decoder (`tx3-resolver`) and every SDK encoder validate against this
    one file so server and client agree byte-for-byte.
