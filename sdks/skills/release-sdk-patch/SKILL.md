---
name: release-sdk-patch
description: Trigger a single-SDK patch release for a core package while preserving the fleet-wide MAJOR.MINOR train.
---

# release-sdk-patch

Trigger a patch-only release for one core SDK package by creating and pushing the SDK's canonical release tag.

## When to use

- "Publish a Rust bugfix patch."
- "Release python-sdk patch 1.0.4 without touching other SDKs."
- "Cut a Go module patch tag only."

Do not use this skill for coordinated `MAJOR.MINOR` train changes; use `release-synced` instead.

## Scope

Core SDK packages only:

- `rust-sdk/sdk`
- `web-sdk/sdk`
- `go-sdk/sdk`
- `python-sdk/sdk`

Integrations/plugins/examples are out of scope.

## Inputs

Required:

- Target SDK (`rust`, `web`, `go`, or `python`).

Optional:

- Explicit patch version. If omitted, compute next patch from existing tags for that SDK.
- Tag annotation message.

## Procedure

1. Read `sdks/sdk-spec/release-policy.md` and enforce its constraints.
2. Determine current fleet `MAJOR.MINOR` train from core SDK package versions.
3. Validate the target SDK's package/module release remains on the same `MAJOR.MINOR` train.
4. Compute the target release tag:
   - Rust/Web/Python: `vMAJOR.MINOR.PATCH`
   - Go: `sdks/vMAJOR.MINOR.PATCH`
5. Ensure the tag does not already exist.
6. Create an annotated tag in the target SDK repository.
7. Push the tag to origin and report the resulting release workflow URL.

## Guardrails

- Block if the requested release would change `MAJOR` or `MINOR`.
- Block if the target SDK's package version and requested tag are inconsistent.
- Never rewrite or force-push tags.
- Do not run manual publish commands; rely on tag-triggered GitHub workflow automation.

## Example

Python patch release on train `1.2`:

- target SDK: `python`
- pushed tag: `v1.2.4`
