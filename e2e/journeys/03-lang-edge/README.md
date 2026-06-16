# 03-lang-edge

Coverage journey focused on the *newest* language additions, complementing 02-lang-tour's broad
surface: user-defined functions (`fn` with `let`), the `*` and `/` operators, parametric tuples
(`Tuple<…>` types, literals, and indexing), and `///` doc-comments. Swaps in this directory's
`main.tx3` and pushes it through `check → build → inspect tir`.

- **Scope:** compile/lower only (no devnet round-trip).
- **Fixture:** `main.tx3`.
- **Capability:** needs `tx3c >= 0.22` (`#@ min-tx3c: 0.22.0`); skipped on older channels (e.g. stable's 0.21).
