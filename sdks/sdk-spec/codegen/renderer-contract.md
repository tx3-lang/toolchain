# Renderer Contract

The renderer is `tx3c codegen` (`tx3/bin/tx3c/src/codegen.rs`), built on the Rust [`handlebars`](https://docs.rs/handlebars) crate. This page defines what templates may assume about it.

## Data context

The renderer constructs exactly one top-level key: `tii` — the parsed TII JSON. All template variables MUST be addressed relative to `tii`. No other context keys are guaranteed.

## Helpers

The renderer registers a fixed set of helpers in `register_helpers` (`tx3/bin/tx3c/src/codegen.rs`). Templates MAY use them; templates MUST NOT assume any others.

- **Case converters** — `pascalCase`, `camelCase`, `snakeCase`, `constantCase`, `lowerCase`. Each takes one string and returns the same string in the named case (via the `convert_case` crate).
- **`schemaTypeFor <schema> <language>`** — maps a JSON Schema node to a language-native type name. Recognized languages: `rust`, `typescript`, `python`, `go`. The full mapping (primitives, arrays, objects with `additionalProperties`, named `$ref`s like `Bytes`/`Address`/`UtxoRef`/`AnyAsset`) is defined in the same file — do not duplicate it in templates; rely on the helper.
- **`json <value>`** — serializes any TII node (object, array, or scalar) to a compact JSON string. Use it to embed structured data such as `tii.profiles` and `tii.environment`; plain `{{...}}` interpolation renders a JSON object as the literal `[object]`. Always invoke it triple-stashed (`{{{json ...}}}`) so the quotes are not HTML-escaped.

A plugin that needs a type mapping the helper doesn't cover MUST request the addition upstream rather than hand-rolling per-language logic in the template.

## Output behavior

- Files ending in `.hbs` are rendered as Handlebars templates; the `.hbs` suffix is stripped from the output filename.
- All other files are byte-copied to the output at the same relative path.
- Subdirectory structure is preserved.
- Empty render output skips the write.

See `register_templates` / `render_templates` / `copy_static_files` in `tx3/bin/tx3c/src/codegen.rs` for the implementation.

## What the renderer does not do

- **No version validation.** Any well-formed JSON is accepted as TII. See [versioning.md](versioning.md) for the workaround and the planned fix.
- **No partials, template inheritance, or custom delimiters.** Standard Handlebars syntax is the entire vocabulary.
- **No filesystem or environment access from templates.**

Future spec revisions MAY add helpers; until they do, the set above is the entire contract.
