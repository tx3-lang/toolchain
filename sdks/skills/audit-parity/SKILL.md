---
name: audit-parity
description: Audit every Tx3 SDK against sdks/sdk-spec/ and update sdks/parity-matrix.md. Use when the user asks to check parity, spot drift, or refresh the matrix.
---

# audit-parity

Read the spec, inspect each SDK, and produce an honest parity snapshot.

## When to use

- "Audit the SDKs", "check parity", "where are we drifting?", "refresh the matrix".
- Before starting a cross-cutting change so you know the baseline.
- After a sprint of independent SDK work to catch silent drift.

## Inputs

None required. Optional: a specific capability to focus on (e.g. "only audit §3.5 signers").

## Procedure

1. **Load the spec.** Read `sdks/sdk-spec/api-surface/` and `sdks/sdk-spec/scope.md`. The API surface files define the rows you're auditing; the compliance checklist in `scope.md` is the pass/fail bar.
2. **List the SDKs.** Read `AGENTS.md` for the current inventory. For each SDK folder, note its language, package name, and version from its own manifest (`Cargo.toml`, `package.json`).
3. **For each SDK, for each capability in §3, verify by reading source.** Do not trust the existing matrix cell.
   - Find the symbol: grep for the concept name (e.g. `Tx3Client`, `CardanoSigner`, `waitForConfirmed`, `checkStatus`).
   - Open the file and confirm the capability is actually implemented, not just named.
   - Check it's reachable from the SDK's public entry point (`lib.rs`, `src/index.ts`, etc.). A capability buried in a private module doesn't count.
   - Note the exact file path for ✅ entries.
4. **Check the optional surface (§4 top-level re-exports).** This is often where SDKs drift — an internal symbol exists but isn't exported.
5. **Update `sdks/parity-matrix.md`:**
   - Flip cells to match reality. ✅ / 🚧 / ❌.
   - For ✅ cells, make sure the link points at the actual file.
   - For 🚧 cells, explain what's partial in the Notes column.
   - Update the per-SDK summary section if the set of gaps changed.
   - Bump the **Snapshot date** line to today.
6. **Report to the user:**
   - What changed in the matrix (added ✅, new ❌, promoted 🚧 → ✅, etc.).
   - Any surprises (capability named but broken, undocumented capability that isn't in the spec).
   - A short "next best move" recommendation — usually the smallest change that closes the most matrix cells.

## Guardrails

- **You may edit only `sdks/parity-matrix.md`.** Never patch SDK code in this skill — that's what `propagate-change` and `add-sdk-feature` are for.
- **Don't invent capabilities.** If an SDK exposes something useful that isn't in the spec, flag it to the user and ask whether to add it to `sdks/sdk-spec/api-surface/`. Do not silently add matrix rows.
- **Read the source, don't guess from names.** A method called `waitForConfirmed` that just returns `Promise.resolve(null)` is ❌, not ✅.
- **Be specific in Notes.** "Partial" is useless. "Missing `checkStatus` wire call; returns hardcoded Confirmed" is actionable.

## Example run (abridged)

> User: audit parity.
>
> 1. Load `sdks/sdk-spec/api-surface/`. Rows: 3.1 protocol loading (tii.md), 3.2 TRP (trp.md), 3.3 facade + 3.4 parties + 3.6 profiles + 3.7 wait modes (facade.md), 3.5 signers (signers.md), 3.8 errors (errors.md), 3.9 args (args.md).
> 2. Inventory: `rust-sdk` (0.9.2), `web-sdk/sdk` (0.7.0).
> 3. Grep rust-sdk: all rows ✅, all reachable from `lib.rs`.
> 4. Grep web-sdk: `TRPClient` present, no `checkStatus`; no `Tx3Client`, no `Party`, no signer module. All §3.3–§3.8 → ❌.
> 5. Update matrix, bump date, summarize.
> 6. Report: no changes from baseline; next best move = implement TRP `checkStatus` in web-sdk (unblocks §3.7).
