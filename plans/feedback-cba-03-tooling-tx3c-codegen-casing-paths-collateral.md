# Plan: tx3c TS codegen — snake_case args, stale `gen` paths, collateral computation

Status: **open / not started**
Scope: `tooling/tx3c` (TypeScript codegen templates + collateral
handling in the TRP build/submit path). Touches `sdks/web-sdk` templates
indirectly.
Origin: user feedback doc (Asteria, Bodega, Githoney, Strike, Appendix).

## Context

Three coupled codegen defects:

A. **camelCase vs snake_case.** Generated TS snippets emit function
   arguments in camelCase, but the TRP expects snake_case. Affects
   Asteria `create_ship`, Bodega `buy/sell_position_yes/no`, Githoney
   `createBountyWithLovelace`, Strike staking. Doc note [d]: "the type
   generated for TypeScript doesn't match what the requirements are for
   TRP." This is a codegen template issue, not a per-protocol issue.

B. **Stale import paths.** TS snippets import `Client` from
   `./gen/typescript/<protocol>` but should point at `protocol.ts`, and
   `gen` has been renamed to `codegen`. Also the docs `requirements.txt`
   real path is `/gen/python/ticketing-2026` (stale `gen`).

C. **No collateral computation from protocol params.** Asteria
   create-ship CBOR had insufficient collateral; there's no way to
   compute collateral based on protocol parameters. (Related: Bodega
   change-output min_ada errors `(-32004) minimum lovelace requirement
   was not met` — possibly auto-fixed 2026-06-23, verify.)

## Approach

1. In the TS codegen templates, emit invoke-param names in snake_case
   to match the TIR/JSON-Schema param names (which are already
   snake_case in the `.tx3` source). Stop applying `camelCase` to
   param names; reserve `camelCase` for TS method/type identifiers only.
   Add a codegen test asserting param-name casing matches the schema.
2. Fix the snippet import path template: point at `protocol.ts` (or the
   codegen output path), drop the stale `gen/` segment. Audit the docs
   site snippet generator for the same `gen`→`codegen` rename.
3. Implement collateral computation from protocol parameters (or expose
   a hook so the TRP can size collateral from `tx3c`-emitted metadata).
   Verify Bodega min_ada change-output case is resolved.

## References

- `plans/sdk-codegen-v1beta0-migration.md` — the codegen template
  contract, helpers (`camelCase`, `snakeCase`, `schemaTypeFor`), and
  `.hbs`-vs-static rule.
- `tx3/bin/tx3c/src/codegen.rs` — helpers, template rendering.
- `tooling/AGENTS.md`.

## Verification

- Regenerate Asteria/Bodega/Githoney/Strike clients; confirm invoke args
  are snake_case and the txs resolve + submit.
- `trix codegen` for a sample protocol emits `protocol.ts` import paths
  (no `gen/`).
- Asteria create-ship collateral is sufficient; Bodega sell txs no
  longer hit `(-32004) minimum lovelace requirement`.
- Run `trix` e2e codegen harness.

## Depends on / unblocks

- Depends on nothing. Pairs with cluster 6 (protocols) for end-to-end
  validation. Fix the casing/paths before re-running protocol fixtures.
