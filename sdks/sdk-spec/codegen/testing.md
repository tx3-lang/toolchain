# Testing

Every SDK shipping a codegen plugin MUST verify it with a **render-fixture check**. Without it, the plugin cannot claim a ✅ in the codegen rows of the [parity matrix](../../parity-matrix.md).

The check exercises the plugin templates and `tx3c` — an integration *above* the SDK — not the SDK runtime. It therefore MUST NOT live in the SDK's test suite (no `*_test` source, no unit or e2e test). It is a dedicated `codegen` job in the SDK repo's CI workflow that drives `tx3c` directly from the shell. Any script the job needs is a CI artifact — keep it under `.github/` — never an SDK source or test artifact.

## What the check MUST do

1. Invoke `tx3c codegen`, with `--tii` pointing at a `v1beta0` transfer fixture, `--template` at the SDK's own `.trix/client-lib/`, and `--output` at a scratch directory. Do NOT generate TII at check time — the compiler is out of scope per [scope.md](../scope.md); use a committed fixture.
2. Assert successful exit and that every expected output file is present.
3. **Compile or type-check the rendered output** in the target language (`tsc --noEmit`, `cargo check`, `go build`, a Python import). The rendered crate/package MUST be built against the runtime SDK **in the same checkout** — Cargo `[patch.crates-io]`, npm workspaces / `npm link`, Python editable install (`pip install -e`), or the language's equivalent. A PR that lands SDK and template changes in lockstep is thus verified against itself; the published-registry version (which may lag the source) is not what's under test on a PR. A successful `tx3c` invocation that produces uncompilable bindings is a failure.

   A separate registry-fidelity job (compiling against the package published to the language registry at the version the manifest pins, with no overrides) is RECOMMENDED at release time or as a post-merge job, but is not on the PR-CI path: on a PR that advances the template ahead of a release, registry resolution is structurally impossible because the SDK version it needs is not yet published.
4. **Smoke-check the generated surface** — confirm the protocol-identity constants, the per-transaction types, and the profile surface are present — so a template that compiles but drops content is caught.

## CI gating

The check MUST run on every PR and push as a dedicated `codegen` job, parallel to `unit` and `e2e`. It does not need TRP secrets and MUST NOT be gated behind the e2e job.

`tx3c` is provisioned with the `tx3-lang/actions/setup` action. A plugin written against an unreleased `tx3c` feature SHOULD pin the action to the channel that carries it (e.g. `channel: beta`) until it reaches `stable`.

## Determinism

Same TII + same template + same `tx3c` version MUST produce byte-identical output. Build-time identifiers MUST be sourced from the TII (e.g., `tii.protocol.version`), never from the host system.

A **golden-file snapshot** check (rendered output committed to the SDK repo, test fails on unexpected diff) is RECOMMENDED — it makes template changes visible in code review — but not required.

## Cross-fleet check

Until a unified workflow in `tx3/` renders all four plugins on every `tx3c` PR (planned; see [versioning.md](versioning.md)), the cross-fleet check is manual:

```bash
for sdk in web-sdk rust-sdk python-sdk go-sdk; do
    tx3c codegen \
        --tii sdks/sdk-spec/test-vectors/transfer/transfer.tii \
        --template sdks/$sdk/.trix/client-lib \
        --output /tmp/codegen-check/$sdk
done
```
