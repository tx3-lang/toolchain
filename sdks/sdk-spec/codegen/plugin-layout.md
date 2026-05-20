# Plugin Layout

A codegen plugin is a directory of template files inside an SDK repository, discovered by `trix codegen` via a GitHub `(repo, path, ref)` tuple.

## Convention path

First-party plugins MUST live at `.trix/client-lib/` at the SDK repo root. The four known plugins and their pin defaults are enumerated in `trix/src/config/convention.rs` (`KnownCodegenPlugin`, `KNOWN_CODEGEN_PLUGINS`, `CURRENT_CODEGEN_VERSION`); see that file for the authoritative list and references.

Third-party plugins MAY use any path but SHOULD follow the same convention for discoverability.

## File naming

The renderer walks the template directory recursively. Files ending in `.hbs` are rendered as templates (with the suffix stripped from the output); everything else is byte-copied. See [renderer-contract.md](renderer-contract.md#output-behavior).

A plugin SHOULD organize its templates into one `.hbs` per output file and SHOULD include a "this file is auto-generated" header comment in every rendered file.

## Required files

A plugin MUST emit the symbols defined in [generated-surface.md](generated-surface.md). Beyond that, file count and layout are unconstrained.

## Addressing from `trix.toml`

A consumer enables a plugin via one or more `[[codegen]]` blocks:

```toml
# First-party
[[codegen]]
plugin = "ts-client"        # one of the names enumerated in convention.rs
output_dir = "gen/ts"       # optional; defaults to ~/.tx3c/codegen/<job_id>/
job_id = "web-bindings"     # optional; defaults to the plugin name

# Third-party / local
[[codegen]]
plugin = { repo = "acme/tx3-kotlin", path = "client-lib", ref = "v0.3.0" }
```

Resolution rules live in `trix/src/config/convention.rs` (`CodegenPluginConfig`, `CodegenConfig::{job_id, output_dir}`). An absolute local `path` skips the GitHub download, which is useful during plugin development.

## Ref policy (MUST)

A plugin's ref MUST be a stable, immutable git reference (tag or commit SHA). Branches — including `main` — MUST NOT be used: templates are coupled to TII schema versions (see [versioning.md](versioning.md)) and a moving branch breaks reproducibility.

The canonical ref name for first-party plugins is `codegen-v<TII-version>` (e.g., `codegen-v1beta0`). Third-party plugins MAY choose any naming scheme as long as the ref is immutable.
