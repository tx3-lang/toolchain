---
name: propagate-change
description: Port a change that landed in one Tx3 SDK to all the others, idiomatically. Use when the user says "SDK X just got feature Y, bring the others up to parity".
---

# propagate-change

Take a change that already landed in one SDK and produce the equivalent idiomatic change in every other SDK.

## When to use

- "I just shipped X in the Rust SDK, port it to web."
- "Feature Y is in web-sdk, bring Rust up."
- "Here's a commit in one SDK — make the others match."
- Not for brand-new capabilities that don't exist anywhere yet — use `add-sdk-feature` for that.

## Inputs

At least one of:
- A commit hash, PR number, or branch in the source SDK.
- A diff or patch file.
- A prose description of the change + pointer to the touched files.

If the user doesn't provide any of these, ask for them before proceeding. Don't guess the source of truth.

## Procedure

1. **Understand the source change.**
   - Read the diff. Identify: what capability it adds/changes, which public surface is touched, which tests cover it.
   - Map the touched symbols to their glossary terms in `sdks/sdk-spec/glossary.md`. If the change introduces a new concept not in the glossary, stop and escalate — this is an `add-sdk-feature` task, not a propagation.
2. **Check the spec and matrix.**
   - Is this capability in `sdks/sdk-spec/api-surface/`? If no, the spec is stale. Ask the user whether to update the spec first (normative) or mark the change as experimental.
   - Look at `sdks/parity-matrix.md` for the current state of the affected row(s) in every SDK.
3. **For each target SDK, design the idiomatic equivalent.**
   - Read the target SDK's existing conventions: module layout, error type, async model, builder style, test framework. Match them.
   - Translate glossary names to the host language's casing only — never meaning.
   - Identify the files to touch. Prefer editing existing modules over creating new ones.
   - Call out dependencies: if the target SDK is missing a prerequisite (e.g. web-sdk lacks `checkStatus`, so you can't port `waitForConfirmed`), block on the prerequisite and surface it to the user.
4. **Implement per SDK, one at a time.**
   - Mirror the source's test coverage. A ported change without an equivalent test is incomplete.
   - Run the target SDK's local checks (`cargo build && cargo test`, `npm run type-check && npm test`) from within that SDK's directory.
5. **Update `sdks/parity-matrix.md`:**
   - Flip the affected rows for the target SDK(s).
   - Bump the snapshot date.
6. **Report:** what was ported where, what tests were added, what remains blocked on prerequisites.

## Guardrails

- **Idiomatic first.** If the source uses a consuming `self`-builder and the target language doesn't have ownership semantics, adapt. Don't mechanically translate.
- **Naming parity, not shape parity.** Step names (`resolve`, `sign`, `submit`, `waitForConfirmed`) are fixed. Argument lists, types, and return shapes are free to change.
- **Don't broaden scope.** If the source change only added `Ed25519Signer::from_hex`, don't also refactor the signer module in the target. One change, ported.
- **Block on prerequisites, don't fake them.** If you need `checkStatus` to port `waitForConfirmed` and the target SDK doesn't have it yet, say so and stop.
- **Use the repo commit convention.** Every commit follows Conventional Commits 1.0.0 (the `lang-factory` repo-wide convention; see `sdks/AGENTS.md` for the per-SDK vs wrapper scope vocabulary). The source commit message is *not* propagated verbatim; each target SDK gets its own commit written to that convention.

## Example flow

> User: I landed `Ed25519Signer::from_mnemonic` in rust-sdk (commit abc123). Port it to web.
>
> 1. Read diff: new method on `Ed25519Signer`, BIP39 parsing, test in `signer.rs`.
> 2. Glossary check: `Signer`, `Ed25519Signer` — both in §2, in spec §3.5. Good.
> 3. Matrix: `Ed25519Signer` row = ❌ in web-sdk. Prerequisite: web-sdk has no `Signer` interface at all.
> 4. Block: "Can't port `from_mnemonic` in isolation — web-sdk is missing §3.5 entirely. Route this through `add-sdk-feature` for the full signer surface, not `propagate-change` for one method."
> 5. Report blocker to user.
