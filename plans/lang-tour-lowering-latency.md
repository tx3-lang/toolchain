# Plan: feature-dense lowering latency (lang-tour)

Status: **open / not started**
Scope: `lang/tx3` — the analyze→lower passes in `crates/tx3-lang` and the Cardano
lowering in `crates/tx3-cardano`.
Related: the e2e fixture `e2e/journeys/02-lang-tour/main.tx3` reproduces it.

## Context

On the `02-lang-tour` fixture (~70 lines), `trix build` and `trix inspect tir`
each take **~14s**, versus sub-second for the basic transfer. The emitted TIR
shows the `source` input-resolution expression
(`EvalParam.ExpectInput["source", { … }]`) re-embedded **dozens of times** — once
per `source.fieldN` access and per element of the `...source` record spread in
`output named_output`. The lowering looks like it expands input resolution
combinatorially instead of resolving an input once and referencing it.

## Approach

Profile `tx3c` build + lower on the `02-lang-tour` fixture and find which pass
duplicates the node. Likely fix: common-subexpression / memoization of an input's
resolved representation so property accesses and spreads reference a single
resolved node rather than re-deriving the full `ExpectInput` each time. Confirm
which pass duplicates before choosing where to cut.

## Verification

- Re-run `./e2e/run.sh --journey 02-lang-tour --verbose`; `trix build` and
  `trix inspect tir` drop from ~14s toward the basic-transfer baseline.
- The resulting TIR is semantically unchanged — the resolver still sees the same
  effective values (byte-identical, or provably equivalent).
- Optionally add a soft time budget to the journey once the target is known.
