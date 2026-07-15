# Plan: fix input-reference datum reading (tx3-lang #286)

Status: **open / not started**
Scope: `lang/tx3` (resolver) — `tx3-resolver/src/interop.rs`,
`from_json()`, and the `reference { datum_is }` resolver path.
Origin: user feedback doc (Githoney Bounty failures); GH issue
https://github.com/tx3-lang/tx3/issues/286.

## Context

Githoney `createBountyWithLovelace` fails with
`(-32006) expected assets, got EvalBuiltIn(Add(...))` — root cause is
reading the settings input-ref datum. Hardcoding
`settings.bounty_creation_fee` shifts the error to
`(-32004) transaction values are not preserved correctly`. Separately,
`main.tx3` fails to build once the updated bounty-datum code is present
(builds when the datum block is commented out).

This is the same root cause already documented in
`plans/tx3-protocol-limitations.md` ("Reference datum fields only usable
in datum construction" — Bodega) and the `datum_is` partial resolution
noted for Fluid/Indigo: the resolver handles `ref.field` in **output
datum construction** but NOT in **amount expressions** (`Ada(...)`,
`AnyAsset(...)`, `min_amount`, change). Multi-level access
(`ref.field.subfield`) also still fails.

## Approach

1. In the resolver, when a `reference` block carries `datum_is`,
   resolve `ref.field` (and nested paths) to the **decoded datum value**,
   not the UTxO's `Assets` value. Currently the accessor resolves to
   `Assets` and `property index N not found in Assets([...])`.
2. Extend field-access evaluation to amount-expression context
   (`Ada`, `AnyAsset`, `min_amount`, change math) — not just datum
   construction. This unblocks Bodega `pi_envelope_amount` /
   `pi_share_policy_id`, Indigo oracle-derived params, and Fluid
   `payment_ada` + 4 oracle params.
3. Support multi-level access (`ref.field.subfield`) — needed for Fluid
   Charli3 nested datum and Indigo variant-type datum access.
4. Fix the Githoney `main.tx3` build failure triggered by the updated
   bounty datum (likely a parser/resolver panic on the new datum shape).
5. Add regression fixtures: a protocol tx that reads a ref-datum field
   into an `Ada(...)` amount and into an `AnyAsset(...)` policy/name.

## References

- `plans/tx3-protocol-limitations.md` — Bodega "Reference datum fields
  only usable in datum construction"; Fluid "Reference datum access —
  PARTIALLY RESOLVED".
- `tx3-resolver/src/interop.rs` — `from_json()` (Int/Bool/Bytes/Address/
  UtxoRef only).
- tx3 PRs #316, #317, #318 (prior partial fixes).

## Verification

- `cargo test` in `lang/tx3` + `tx3-resolver`.
- Githoney `main.tx3` builds with the updated bounty datum uncommented.
- `createBountyWithLovelace` resolves + submits on preprod without the
  `(-32006)` / `(-32004)` errors.
- Bodega `buy_position_yes` resolves with `pi_envelope_amount` /
  `pi_share_policy_id` read from ref datum (param drop confirmed).

## Depends on / unblocks

- Unblocks `protocols/githoney` build + runtime; reduces Bodega/Fluid/
  Indigo caller params. No upstream dep; do first.
