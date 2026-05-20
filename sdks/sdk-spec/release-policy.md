# Release Policy

This document defines the normative cross-SDK release and publish policy for the Tx3 SDK fleet.

This policy applies to the core SDK package in each repository only:

- `rust-sdk/sdk` (`tx3-sdk` on crates.io)
- `web-sdk/sdk` (`tx3-sdk` on npm)
- `go-sdk/sdk` (`github.com/tx3-lang/go-sdk/sdk` module)
- `python-sdk/sdk` (`tx3-sdk` on PyPI)

Integrations, plugins, examples, and helper packages are out of scope for this policy.

Keywords **MUST**, **SHOULD**, and **MAY** are interpreted as described in `sdk-spec/README.md`.

---

## Version policy

- All SDKs MUST share the same `MAJOR.MINOR` release train.
- Patch versions MAY advance independently per SDK.
- Any release that changes `MAJOR` or `MINOR` MUST be coordinated across all SDKs.
- A patch release in one SDK MUST NOT change its `MAJOR.MINOR` relative to the fleet train.

This policy governs new releases after adoption. Historical tags published before adoption MAY reflect older versioning practice.

Examples:

- Valid: Rust `1.2.4`, Web `1.2.1`, Go `1.2.3`, Python `1.2.9`
- Invalid: Rust `1.3.0` while Web/Go/Python remain `1.2.x`

---

## Tag-driven release policy

- SDK releases MUST be triggered by pushing a Git tag.
- Release workflows MUST NOT publish from branch pushes, pull requests, or manual dispatch alone.
- The tag version MUST match the SDK release version (or module release version for Go).

Canonical tag formats:

| SDK | Tag format |
|---|---|
| `rust-sdk` | `vMAJOR.MINOR.PATCH` |
| `web-sdk` | `vMAJOR.MINOR.PATCH` |
| `python-sdk` | `vMAJOR.MINOR.PATCH` |
| `go-sdk` | `sdks/vMAJOR.MINOR.PATCH` |

---

## Per-SDK publish mechanics

Each SDK MAY use its language-native toolchain for actual publishing, but MUST preserve the same policy semantics above.

- Rust SHOULD publish via `cargo publish`.
- Web SHOULD publish via `npm publish`.
- Python SHOULD publish via `python -m build` + `twine upload` (or trusted PyPI equivalent).
- Go MUST publish by module-semantic Git tags (`sdks/v...`); no package registry upload step is required.

---

## Required release workflow checks

Each SDK repository MUST implement a release workflow that:

1. Triggers on the SDK's canonical tag pattern.
2. Parses and validates semver from the tag.
3. Verifies the tag version matches the SDK package version declaration when applicable.
4. Runs language-appropriate validation prior to publish (for example unit tests and build checks).
5. Publishes using the language-native toolchain or module tagging convention.
6. Fails fast and clearly when credentials or required release inputs are missing.

---

## Operational release modes

- **Synced train release:** coordinated `MAJOR.MINOR` release across all SDKs, each with its own patch value.
- **Single-SDK patch release:** patch-only release for one SDK, preserving the shared fleet `MAJOR.MINOR`.

The `sdks/skills/` skills used to run these modes MUST enforce this policy and block invalid tag/version operations.
