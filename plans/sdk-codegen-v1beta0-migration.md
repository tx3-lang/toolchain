# Plan: migrate the SDK bindgen templates to `codegen-v1beta0`

Status: **open / not started — urgent (beta channel already ships the pair)**
Scope: cross-cutting — the four SDK submodules under `sdks/`
(`sdks/web-sdk`, `sdks/rust-sdk`, `sdks/python-sdk`, `sdks/go-sdk`); no change
in `trix`/`tx3` (the consuming side already shipped).
Origin: accepted follow-up from the trix↔tx3c delegation work
(`trix` 0.22.0, tx3 0.18.0; ADR `trix/design/004-toolchain-delegation.md`).

## Context

`trix` codegen no longer renders bindings in-process. The legacy in-process
codegen module was removed; `trix codegen` now delegates entirely to
`tx3c codegen` (`trix/src/commands/codegen.rs` → `spawn::tx3c::codegen`).

For the four **built-in** SDK plugins, `trix/src/config/convention.rs`
resolves each to a GitHub repo + a templates path + a ref:

- repos: `tx3-lang/{web,rust,python,go}-sdk`
- path: `.trix/client-lib`
- ref: `CURRENT_CODEGEN_VERSION` — now hard-pinned to **`codegen-v1beta0`**
  (was `bindgen-v1alpha2`; the `unstable` gate was collapsed).

The old `bindgen-v1alpha2` ref went with the now-deleted in-process codegen.
The SDK repos **do not yet publish a `codegen-v1beta0` ref** carrying
templates written against the `tx3c codegen` contract. Until they do,
`trix codegen <built-in plugin>` is broken for end users — and the **beta
channel now installs trix 0.22.0 + tx3c 0.18.0** (`toolchain`
`manifest-beta.json`, commit `b644869`), so beta users hit this today. This
was a knowingly-accepted gap; this plan closes it.

## The `tx3c codegen` template contract

Templates must be authored against what `tx3c codegen` actually feeds them
(`tx3/bin/tx3c/src/codegen.rs`):

- **Inputs:** `tx3c codegen --tii <file> --template <dir> --output <dir>`.
  `trix` fetches the ref, extracts the templates path, and invokes this per
  protocol (project + each interface), nesting output under
  `<output_dir>/<name>/`.
- **Template data:** a single JSON context `{ "tii": <parsed TII> }` — the
  whole TII document (protocol, parties, transactions with `params`
  JSON-Schema + hex-CBOR `tir`, profiles). Templates read `tii.*`.
- **Engine:** Handlebars. `*.hbs` files are rendered (the `.hbs` suffix
  stripped for the output name); **all other files are copied verbatim**
  (static lib code). Empty render output ⇒ file skipped.
- **Helpers available:** `pascalCase`, `camelCase`, `constantCase`,
  `snakeCase`, `lowerCase`, and `schemaTypeFor <schema> <language>` which
  maps a JSON-Schema node to a language type (`rust|typescript|python|go`;
  refs like `Address`/`Bytes`/`UtxoRef`, primitives, `array`,
  `object`+`additionalProperties`, fallback to the language's "any").

## Approach (per SDK repo, identical shape)

1. **Create the `codegen-v1beta0` ref** (branch; tag once validated) with a
   `.trix/client-lib/` directory containing:
   - `*.hbs` templates that emit the generated client from `{{tii.*}}`
     using the helpers above (transactions, params types via
     `schemaTypeFor`, party/env wiring).
   - the static runtime lib files (copied verbatim).
   Port intent from the existing `bindgen-v1alpha2` templates, re-targeted
   from the old in-process data shape to the TII JSON context.
2. **Keep the path `.trix/client-lib`** (matches `convention.rs`; the code
   comment about moving to `bindgen/client-lib` is a *future* change — do
   not move it without a paired `convention.rs` edit).
3. **Validate end-to-end** before tagging (see Verification).
4. **Tag/publish** the ref so `trix` (which fetches `codegen-v1beta0`)
   resolves it.

Recommended order: **rust-sdk first** (compiles locally, fastest feedback
loop, reuse the `trix` e2e harness), then typescript/python/go.

## Critical references

- `trix/src/config/convention.rs:236-268` — plugin repos, `path`, ref.
- `trix/src/commands/codegen.rs`, `trix/src/spawn/tx3c.rs::codegen` —
  fetch + invocation, per-protocol nesting.
- `tx3/bin/tx3c/src/codegen.rs` — helpers, `schemaTypeFor` mapping,
  `.hbs`-vs-static rule, empty-skip.
- `trix/tests/e2e/fixtures/codegen-template/bindings.txt.hbs` — a minimal
  working reference template exercising the contract.
- TII shape: `tx3/bin/tx3c/src/tii/types.rs` (and the `tii/` spec repo).

## Verification (per SDK, end-to-end)

- Point a scratch project's `[[codegen]]` at the new ref (or rely on the
  built-in plugin once tagged); run `trix codegen`.
- The generated client **builds/compiles** in that language and matches the
  SDK runtime API; run the SDK's own example/tests against it.
- Diff generated output against the pre-migration `bindgen-v1alpha2` result
  for an unchanged protocol — intentional differences only.
- Add/extend a `trix` e2e (mirror `codegen_deps`) that runs the real ref
  for at least rust-sdk in CI.

## Risks / notes

- **User-visible breakage window is open now** on beta. Until at least one
  SDK lands, options: hold the beta announcement, or document a pin
  (`tx3up install --release` to an older toolchain) as a stopgap.
- `stable` channel is **not** yet bumped to this pair — do not bump it
  (`toolchain/manifest-stable.json`) until all four SDKs ship and validate.
- If a clean port proves slow, a fallback is reintroducing the legacy
  codegen behind a flag in `trix` — explicitly rejected as the long-term
  path (see ADR 004) but available as an emergency lever.
