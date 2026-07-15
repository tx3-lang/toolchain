# Plan: docs site + tx3.land registry UX fixes

Status: **open / not started**
Scope: `services/docs` + `services/registry` (tx3.land UI).
Origin: user feedback doc (General, Bodega, Appendix, General "UI
lies").

## Context

A. **Try-out tab gating.** tx3.land lists profiles/channels in the
   try-out tab that don't exist (cluster 6). UI should only offer
   channels with an actual `.tii` profile.
B. **Snippet import paths.** TS snippets import from
   `./gen/typescript/<protocol>`; should be `protocol.ts`, and `gen`
   →`codegen` (ties to cluster 3).
C. **Refresh-order inconsistency.** On each load, the order of
   transactions vs parties in the UI is not consistent.
D. **Bodega metadata.** Homepage should be `https://www.bodegamarket.xyz/`.
   `project_info_ref` is hard to access — add a listable view; passing
   the ref should be unnecessary when using tx3 (see cluster 1 — once
   ref-datum reading works, the ref param can drop).
E. **Bodega config snippet** sets the user's own address as the
   position-script address. Doc confirms this is a **web-snippet-only**
   detail, not a protocol/tx3 bug — fix the snippet generator to use the
   script address from env, and put `signer` on `withParticipant` (Hydra
   has the same misplaced-signer issue: `withCommitScript` vs
   `withParticipant`).

## Approach

1. Registry: gate the try-out tab on actual profile presence (read the
   `.tii` / registry manifest); hide channels with no profile.
2. Docs/registry snippet generator: fix import paths (cluster 3), drop
   `gen/`, point at `protocol.ts`.
3. Registry: stabilize transactions/parties ordering (sort by a stable
   key; don't rely on map iteration).
4. Bodega: update homepage metadata; add a `project_info_ref` listing;
   once cluster 1 lands, drop the `project_info_ref` caller param.
5. Snippet generator: put `signer` on `withParticipant` (Hydra) and use
   env script addresses rather than the user's address for
   `withPositionscript`/`withDepositscript`/etc. (Bodega/Hydra).

## References

- `services/AGENTS.md` (registry + docs).
- `services/skills/publish-docs-site/`.
- Bodega/Hydra snippet examples in the doc.

## Verification

- Try-out tab only shows channels with real profiles.
- Snippets import from `protocol.ts`; no `gen/`.
- Transactions/parties order is stable across reloads.
- Bodega homepage link correct; `project_info_ref` listed.
- Hydra/Bodega snippets place `signer` correctly and use env script
  addresses.

## Depends on / unblocks

- Depends on clusters 1, 3, 6 for the param/ref drops. Publish docs
  site last per `AGENTS.md` dependency direction.
