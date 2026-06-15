---
name: verify-protocols
description: Verify (do not release) the protocols/ grouping — re-check the open-tx3 .tx3 fixtures parse/check against the newly released tx3c/trix and report breakages.
---

# verify-protocols

The `protocols/` grouping holds third-party `.tx3` protocol definitions (the `open-tx3` org) used as
real-world fixtures. They are **not released** — the grouping's release-equivalent is *verification*:
confirm the new toolchain still parses and checks them, and report any breakage. Instantiates the
umbrella [`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md), specializing
it to a verify-only pass with no publish gate.

## When to use
- Invoked by the `release-toolchain` orchestrator near the end of a wave, to catch a toolchain change
  that breaks real protocols before the channel ships.
- Standalone to check the protocol fixtures against the current toolchain.

Do not use to publish or tag anything — protocols have no release artifact.

## Scope
- All `protocols/<name>/` submodules (the `open-tx3/*-protocols` repos): `.tx3` files only.

## Inputs
- `upstream_versions` — the released `tx3c` / `trix` to verify against.
- `target_channel`, `scope` per the contract.

## Procedure
1. **Map scope.** Every in-scope `protocols/<name>` is a `.tx3` fixture set.
2. **No pins to bump** — protocols don't pin the toolchain; they consume it as a tool.
3. **Verify** each in-scope protocol against the released toolchain: run the project's check
   (`trix check` in the protocol dir, or `tx3c` parse+analyze) using the just-released `tx3c`/`trix`.
   Collect parse/analyze diagnostics. (The `tx3-mcp` `tx3_check` tool is an equivalent programmatic
   path if available.)
4. **No gate** — nothing to publish.
5. **Report** the per-protocol pass/fail. A failure is a *signal about the toolchain release* (a
   forward-incompat or a regression), not a protocol bug to fix here — surface it to the orchestrator so
   the developer can decide whether to hold the channel.
6. **Report Outputs.**

## Outputs
- `skipped: [ { "submodule": "protocols/<name>", "reason": "verified ok | check failed: <diag>" } ]`
- `pointers: [ "protocols/<name>" ]` only if a protocol repo's `main` legitimately advanced (rare)

## Guardrails
- Verify-only — never tag, publish, or auto-edit a protocol's `.tx3` to "fix" a break.
- A check failure blocks nothing by itself; it's information for the channel decision. Report it clearly.
- Use the **released** `tx3c`/`trix` (the versions in `upstream_versions`), not a local dev build.

## Error handling
- **A protocol fails `check` against the new toolchain** — likely a forward-incompat (the `trix` floor
  is the real guard) or a genuine regression. Report which protocol + the diagnostic; let the developer
  decide whether to hold or proceed.
- **A protocol submodule isn't initialized** — `git submodule update --init protocols/<name>` before
  verifying.
