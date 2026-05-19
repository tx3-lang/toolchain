---
name: release-synced
description: Trigger a coordinated MAJOR.MINOR release train across Rust/Web/Go/Python core SDK packages by creating and pushing release tags.
---

# release-synced

Trigger a synchronized fleet release where all core SDK packages share the same `MAJOR.MINOR` train, with per-SDK patch values.

## When to use

- "Ship 1.1 across all SDKs."
- "Cut the next synced train release for the core SDK packages."
- "Bump all SDKs to 2.0 with language-native publish workflows."

Do not use this skill for single-SDK patch-only releases; use `release-sdk-patch` instead.

## Scope

This skill applies only to core SDK packages:

- `rust-sdk/sdk`
- `web-sdk/sdk`
- `go-sdk/sdk`
- `python-sdk/sdk`

Integrations/plugins/examples are out of scope.

## Inputs

Required:

- Target `MAJOR.MINOR` train (for example `1.2`).

Optional:

- Explicit patch per SDK (`rust`, `web`, `go`, `python`).
- If omitted, compute next patch per SDK from existing tags.
- Annotated tag message template.

## Procedure

1. Read `sdks/sdk-spec/release-policy.md` and enforce it as the source of truth.
2. Inspect current SDK versions and tags:
   - Rust: `Cargo.toml` workspace version + `v*` tags.
   - Web: `sdks/package.json` version + `v*` tags.
   - Python: `sdks/pyproject.toml` version + `v*` tags.
   - Go: `sdks/v*` tags (module release marker).
3. Validate all SDKs are ready for the requested train:
   - package versions and requested train agree,
   - no dirty worktrees,
   - remotes available.
4. Compute final tags:
   - Rust/Web/Python: `vMAJOR.MINOR.PATCH`
   - Go: `sdks/vMAJOR.MINOR.PATCH`
5. Create annotated tags in each SDK repository.
6. Push tags to each SDK origin.
7. Report all tag names and the release workflow URLs.

## Guardrails

- Block if any SDK would change `MAJOR.MINOR` unilaterally.
- Block if requested train differs from declared package versions.
- Never rewrite or force-push tags.
- Do not publish directly from this skill; publishing is performed by per-SDK tag-triggered GitHub workflows.

## Example tag push set

- `rust-sdk`: `v1.2.0`
- `web-sdk`: `v1.2.1`
- `go-sdk`: `sdks/v1.2.0`
- `python-sdk`: `v1.2.3`
