# Testing

Every SDK shipping a codegen plugin MUST ship a **render-fixture test**. Without it, the plugin cannot claim a ✅ in the codegen rows of the [parity matrix](../../parity-matrix.md).

## Requirements

The test MUST:

1. Invoke `tx3c codegen` as a subprocess, with `--tii` pointing at the shared fixture `sdks/sdk-spec/test-vectors/transfer/transfer.tii` (copy or symlink locally; do NOT generate TII at test time — the compiler is out of scope per [scope.md](../scope.md)), `--template` pointing at the SDK's own `.trix/client-lib/`, and `--output` at a unique temp dir.
2. Assert successful exit and that every expected output file is present.
3. **Compile or type-check the rendered output** in the target language (`tsc --noEmit`, `cargo check`, `go build`, `pyright`/`mypy`). A successful `tx3c` invocation that produces uncompilable bindings is a failure.

Reference implementation (steps 1–2 only; step 3 not yet present): `sdks/rust-sdk/sdk/tests/codegen.rs`.

## Locating `tx3c`

Resolve in order: `TX3_TX3C_PATH` env var if set, then `tx3c` on `$PATH`. Fail with a clear "install tx3c" message if neither is available — do not silently skip.

## CI gating

The test MUST run on every PR and push, in the SDK's existing unit job. It MAY be deferred to the e2e job if compiling the output requires e2e-only toolchain.

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
