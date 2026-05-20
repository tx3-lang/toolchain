# Tx3 SDK Specification

**Status:** normative. **Audience:** SDK authors and coding agents maintaining the fleet.

This directory defines what a Tx3 SDK *is*, independent of any programming language. It is the contract every SDK in this repository must meet. The requirement keywords **MUST**, **SHOULD**, and **MAY** are used as in RFC 2119.

The currently-most-complete reference implementation is `rust-sdk/` (v0.9.2). When the prose here is ambiguous, the Rust SDK's public surface is the tiebreaker — but only for *what* must exist, never for *how* it is spelled in the target language.

---

## Table of Contents

### Foundations

- [Scope](scope.md) — mission, recommended/optional surfaces, non-goals, and compliance checklist
- [Glossary](glossary.md) — authoritative concept names every SDK must use

### API Surface (required capabilities)

- [Overview](api-surface/) — how the three-tier requirement model works
- [TII / Protocol Loading](api-surface/tii.md) — loading `.tii` files into `Protocol` objects
- [TRP Client](api-surface/trp.md) — low-level `resolve`, `submit`, `checkStatus` operations
- [Facade](api-surface/facade.md) — client workflow, parties, profiles, and wait modes
- [Signers](api-surface/signers.md) — signer interfaces and built-in signer types
- [Error Model](api-surface/errors.md) — discriminated error categories
- [Argument Marshalling](api-surface/args.md) — native value encoding for TRP calls

### Governance

- [Versioning](versioning.md) — release and compatibility policy
- [Release Policy](release-policy.md) — cross-SDK tag-driven release and publish rules
- [Naming Conventions](naming.md) — canonical terms and builder order

### Quality

- [Testing Strategy](testing/) — unit and end-to-end (e2e) test requirements
- [CI Workflow Policy](testing/ci-workflows.md) — required unified CI workflow semantics
- [Documentation Requirements](documentation/) — README template, docstring strategy

### Codegen (optional capability)

- [Codegen Plugin Contract](codegen/) — what an SDK's `.trix/client-lib/` template set must look like, what it consumes, and what it must emit

### Shared Fixtures

- [Test Vectors](test-vectors/) — canonical shared vectors (`.tx3`, `.tii`, `.env`) used by SDK e2e tests
