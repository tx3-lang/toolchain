# Versioning

Codegen has three version surfaces that must move in lockstep:

1. **TII schema version** — `TII_VERSION` in `tx3/bin/tx3c/src/tii/types.rs`.
2. **Plugin template ref** — the immutable git tag a plugin is pinned to (see [plugin-layout.md](plugin-layout.md)). First-party convention: `codegen-v<TII-version>`. Wired through `CURRENT_CODEGEN_VERSION` in `trix/src/config/convention.rs`.
3. **Runtime SDK** — the package the generated bindings import. Must resolve at the version the consumer has installed.

A TII schema change requires all three to move together.

## Compatibility rule (MUST)

A plugin MUST declare exactly one supported TII version, encoded in its ref name. Until the renderer enforces this, plugins SHOULD emit a header comment in every generated file naming both the plugin's target version and the source `tii.version` so mismatches surface in the diff.

## TII bump procedure

When `tx3c` bumps `TII_VERSION` (e.g., `v1beta0` → `v1beta1`):

1. Bump `TII_VERSION` in `tx3/bin/tx3c/src/tii/types.rs`. Regenerate fixtures under `sdks/sdk-spec/test-vectors/`.
2. Bump `CURRENT_CODEGEN_VERSION` in `trix/src/config/convention.rs` to the matching `codegen-v<new>` ref.
3. Update `.trix/client-lib/` templates in each SDK as needed and tag the SDK repo with `codegen-v<new>` (immutable).
4. Mark codegen rows 🚧 in the [parity matrix](../../parity-matrix.md) for SDKs that haven't caught up.

Because step 3 spans N SDK repos, the bump is a multi-PR rollout. The trix release that ships the new `CURRENT_CODEGEN_VERSION` MUST NOT precede the first-party SDK tags.

## Third-party plugins

Third-party plugins MUST publish an immutable tag per supported TII version and state the supported version in their README. They MAY ship parallel tags for multiple TII versions but MUST NOT autodetect and branch internally — Handlebars has no conditional dispatch that would survive a real schema change.

## Relationship to the SDK release train

The fleet-wide `MAJOR.MINOR` sync in [release-policy.md](../release-policy.md) governs the **runtime SDK** packages. Plugin tags (`codegen-v<TII>`) are independent artifacts in the same repos. The SDK's README MUST already declare TII compatibility per [versioning.md](../versioning.md); it SHOULD additionally list the available plugin refs.

## Known gap

The renderer (`tx3/bin/tx3c/src/codegen.rs`) does **not** validate `tii.version` against the plugin's target. Until that lands (planned: `--expected-tii-version` flag on `tx3c codegen`, passed by `trix` based on the plugin ref), the version contract is enforced socially. This spec calls the gap out so it doesn't get lost.
