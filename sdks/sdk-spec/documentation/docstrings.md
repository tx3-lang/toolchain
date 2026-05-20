# Docstring Strategy

Every public symbol (type, function, method, constant) in a Tx3 SDK MUST have a docstring. Docstrings are the primary API reference — they feed generated documentation (rustdoc, TypeDoc, pdoc, godoc) and IDE tooltips.

---

## Format

Use the host language's standard documentation format:

| Language | Format | Example |
|----------|--------|---------|
| Rust | `///` doc comments | `/// Creates a new Tx3Client...` |
| TypeScript | TSDoc `/** */` | `/** Creates a new Tx3Client... */` |
| Python | Triple-quote docstrings | `"""Creates a new Tx3Client..."""` |
| Go | `//` preceding the symbol | `// NewTx3Client creates a new Tx3Client...` |

---

## Required content

Every docstring MUST include:

1. **One-line summary.** A single sentence describing what the symbol does. Start with a verb for functions/methods ("Creates...", "Returns...", "Loads...").
2. **Parameter descriptions.** For every parameter: name, type (if not obvious from the signature), and what it represents.
3. **Return value.** What the function returns and under what conditions.
4. **At least one usage example.** Preferably runnable (Rust doc-tests, TSDoc `@example` blocks). If a full runnable example is impractical, a code snippet showing the call site is acceptable.

## Recommended content

- **Error conditions.** Which errors can be thrown/returned and when. Link to the [error model](../api-surface/errors.md) categories.
- **See-also links.** Cross-reference related symbols (e.g., `ResolvedTx.sign()` should link to `SignedTx`).
- **Since version.** When the symbol was introduced, especially for post-1.0 additions.

---

## What NOT to document

- Private/internal symbols. Document the public contract, not the implementation.
- Self-evident accessors. A getter called `address()` on a `Party` doesn't need a paragraph — a one-liner is fine.
- Implementation details that may change. Focus on the *what* and *why*, not the *how*.

---

## Module-level documentation

Each module (TII, TRP, facade, signers) SHOULD have a module-level docstring that:

1. Explains what the module is responsible for (one paragraph).
2. Lists the key public types/functions.
3. Provides a brief usage overview or links to the quick-start example.

The Rust SDK's `tii/mod.rs` module doc is a good reference for the level of detail expected.
