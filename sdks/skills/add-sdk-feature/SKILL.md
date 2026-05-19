---
name: add-sdk-feature
description: Add a new capability to the Tx3 SDK spec and to every SDK in one coordinated pass. Use when introducing something that doesn't exist in any SDK yet.
---

# add-sdk-feature

Design a new capability at the spec level, then fan it out to every SDK in the fleet.

## When to use

- "Add support for hardware wallet signers across all SDKs."
- "Every SDK needs a `dryRun()` step before `submit()`."
- "We want a `withRetry` policy on the facade."
- Anything net-new: if the capability is already in one SDK, use `propagate-change` instead.

## Inputs

From the user (ask if missing):
- **What the capability is**, in user-facing terms. One sentence.
- **Why** — the motivating use case or bug it addresses.
- **Rough shape** — ideally a code sketch in one language, even a stub. No sketch is OK; you'll design one.
- **Scope** — is this required (§3), recommended (§4), or optional (§5)?

## Procedure

1. **Design the spec delta first.**
   - Pick the right section of `sdks/sdk-spec/`: `api-surface/` (MUST), `scope.md` Recommended Surface (SHOULD), or `scope.md` Optional Surface (MAY).
   - Write the new subsection: name, rationale (one paragraph), minimum shape, reference implementation target, error semantics. Mirror the style of existing subsections.
   - If the capability introduces new concepts, add them to the §2 glossary with the canonical names *before* you write any code. Naming drift starts here.
   - Update §9's checklist if the capability is in §3.
2. **Review the spec delta with the user.**
   - Show them the proposed spec patch.
   - If they're happy, apply it. If not, iterate. Do not write SDK code before the spec is agreed.
3. **Plan per-SDK implementation.**
   - For each SDK in `AGENTS.md`, read the existing code that neighbors the new capability. Pick the idiomatic shape for that language. Don't copy-paste from the reference impl.
   - Identify prerequisites in each SDK. If a target SDK is missing a foundation the new capability depends on, either include the foundation in this task (and the spec delta) or declare that target SDK out of scope and matrix-mark it.
4. **Implement in the reference SDK first (usually `rust-sdk`).**
   - Full implementation + tests + docs. This becomes the "reference implementation" line in the spec.
   - Run the SDK's local checks before moving on.
5. **Fan out to every other SDK.**
   - One SDK at a time. Match the target's conventions.
   - Mirror the reference SDK's test coverage.
   - Run each SDK's local checks.
6. **Update `sdks/parity-matrix.md`:**
   - Add a new row for the capability (if §3) or update existing rows.
   - Mark cells per SDK (✅ everywhere you shipped, ❌ or — for opted-out SDKs).
   - Bump the snapshot date.
7. **Update the per-SDK `README.md`** if the new capability is user-facing.
8. **Report:**
   - Spec diff (summary).
   - List of SDKs updated and test commands run.
   - Any SDK left behind, with an explanation.

## Guardrails

- **Spec-first, always.** Writing code before the spec is how glossaries fracture. If the user pushes back on this, explain that the spec is a contract with future contributors, not paperwork.
- **Same name everywhere.** The whole point of the spec is that `wait_for_confirmed` / `waitForConfirmed` / `WaitForConfirmed` are the same thing. Never negotiate names per-SDK.
- **No partial fleets.** If you can only land the capability in one SDK this session, say so explicitly and log the gap in the parity matrix. Don't silently ship one and forget the others.
- **Idiomatic translation, not mechanical translation.** A Rust `Arc<dyn Signer>` should become a TypeScript `interface Signer` with structural typing, not a hand-rolled `ArcSignerBox` class.
- **Keep the §3 bar high.** If a capability could live in §4 or §5, prefer that. §3 is "every SDK MUST have this"; additions there impose real cost on every maintainer.

## Example flow

> User: add a `dryRun()` step between `resolve()` and `sign()` that calls TRP to validate without locking UTxOs.
>
> 1. Spec: new §3.3a under facade. Glossary: `DryRunResult`. Minimum shape: `ResolvedTx.dryRun() -> DryRunResult` with `ok: bool` + `diagnostics: []`.
> 2. Show spec patch to user → approved.
> 3. Plan: `rust-sdk` has `ResolvedTx` in `facade.rs` — add method next to `sign()`. `web-sdk` needs the facade first → out of scope for this task, mark ❌ and open a follow-up.
> 4. Implement in rust-sdk, test, run `cargo test`.
> 5. Skip web-sdk (blocked on §3.3).
> 6. Matrix: new row "3.3a dryRun" → ✅ rust, ❌ web. Date bumped.
> 7. Report: spec updated, rust-sdk shipped, web-sdk blocked on §3.3 facade work.
