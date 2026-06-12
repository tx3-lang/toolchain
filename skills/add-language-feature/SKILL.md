# Add Language Feature Skill

## Purpose
Guide an end-to-end rollout of a new Tx3 language feature (an operator, expression form,
builtin, or block field) across every layer of the toolchain: spec → grammar/AST →
analysis/lowering → TIR/reduction → downstream consumers → docs → agent skills. The
methodology was battle-tested by the multiply (`*`) and divide (`/`) operator rollouts and
exists so the next feature lands with the same completeness: no exhaustive match left
unhandled, no serde break, no doc or skill left stale, and a clean per-submodule PR trail.

## Prerequisites
- Run from the umbrella repo root with submodules initialized (`git submodule update --init`).
- Rust toolchain (`cargo`) for `core/tir`, `lang/tx3`, `registry`, `tooling/tx3-lift`,
  `tooling/tx3-lsp`.
- `gh` CLI authenticated against the `tx3-lang` org (for the per-submodule PRs).
- Optional but valuable: `tx3-mcp` on PATH for end-to-end `tx3_parse`/`tx3_check`/`tx3_lower`
  verification.

## Context

### The pipeline a feature flows through
A Tx3 source feature traverses these stages; a complete feature touches every one that
applies:

```
tx3.pest (grammar) → ast.rs → parsing.rs (Pratt) → analyzing.rs → lowering.rs
    → tx3-tir model (BuiltInOp / Expression) → reduce/ (constant folding)
    → consumers: registry, tx3-lift, tx3-lsp, vscode-tx3, tx3-cardano
```

### Repos and files per layer

| Layer | Repo (submodule) | Key files |
| --- | --- | --- |
| Spec | `lang/tx3` | `specs/v1beta0/03-lexical-structure.md`, `04-syntactic-grammar.md`, `05-type-system.md` |
| Grammar + frontend | `lang/tx3` | `crates/tx3-lang/src/tx3.pest`, `ast.rs`, `parsing.rs`, `analyzing.rs`, `lowering.rs` |
| TIR + reduction | `core/tir` | `crates/tx3-tir/src/model/v1beta0.rs`, `model/assets.rs`, `reduce/mod.rs` |
| Consumers | `registry` | `backend/src/ast_to_svg.rs` (exhaustive `BuiltInOp` match) |
| Consumers | `tooling/tx3-lift` | `crates/tx3-lift/tests/smoke.rs` (`count_in_builtin`) |
| Consumers | `tooling/tx3-lsp` | `src/visitor.rs` (exhaustive `DataExpr` match) |
| Editor | `plugins/vscode-tx3` | `syntaxes/tx3.tmLanguage.json` (often already covered — verify) |
| Docs | `docs` | `language/data.md` (expressions), `language/assets.md`, others as relevant |
| Agent skills | `plugins/tx3-skills` | `skills/tx3-language/SKILL.md` (operator summary line), `skills/tx3-language/reference/expressions.md` |

`tooling/tx3-mcp` is operator-agnostic (no change for expression features).
`tx3-cardano` matches only `CompilerOp` — reduce folds constants first and unresolved
ops hit the generic coerce fallback, so it typically needs no change; confirm per feature.

### Cross-repo dependency model
Submodules are **independent repos** depending on each other via **crates.io versions**
(`tx3-tir = "x.y.z"`, `tx3-lang = "x.y.z"`), not path deps. To build a dependent against
unreleased upstream changes, temporarily append a patch to the dependent's `Cargo.toml`:

```toml
[patch.crates-io]
tx3-tir = { path = "../../core/tir/crates/tx3-tir" }       # from lang/tx3
# from tooling/* or registry/backend, adjust depth:
# tx3-tir  = { path = "../../core/tir/crates/tx3-tir" }
# tx3-lang = { path = "../../lang/tx3/crates/tx3-lang" }
```

Build/test, then revert **both** files individually (a combined pathspec can fail
silently): `git checkout -- Cargo.toml && git checkout -- Cargo.lock`. Never commit the
patch.

### Serde backward compatibility (TIR)
`BuiltInOp` (and sibling TIR enums) serialize as **name-tagged CBOR** via ciborium —
variants encode as `{"VariantName": [...]}`. **Appending a new variant as the LAST entry
preserves every existing variant's byte encoding** and keeps
`test_decoding_is_backward_compatible` green. Never insert mid-enum or reorder.
Forward compat is inherently breaking: a pre-feature reader fails loudly with
`unknown variant <X>` on new TIR. The real guard is the `trix.toml [toolchain]`
min-version gate — decide with the user whether the producing release bumps it.

### pest / Pratt parser rules
- Later `.op(...)` calls in the PrattParser builder bind **tighter**. Operators that share
  a precedence level go in the **same** `.op(...)` call joined with `|`
  (e.g. `.op(Op::infix(Rule::data_mul, Assoc::Left) | Op::infix(Rule::data_div, Assoc::Left))`).
  A separate `.op(...)` line silently creates a new tier.
- `WHITESPACE`/`COMMENT` are consumed implicitly before infix matching, so tokens that
  prefix comment openers (like `/` vs `//`) don't collide — but adjacent source like `a//b`
  lexes as `a` + line comment. Document such gotchas in spec, docs, and skill.

## Procedure

### 0. Plan and settle semantics first
Before touching code, write a plan that pins down the semantic decisions (see Decision
Guidelines). Identify the **cleanest sibling feature** already in the codebase (e.g. `Mul`
for `Div`, `Sub` for `Mul`) — the implementation is a structured clone of it, and every
place the sibling appears is a place the new feature must appear. Get the user's approval
on the open decisions before implementing.

### 1. core/tir — schema root
1. `model/v1beta0.rs`: append the new `BuiltInOp` variant **last**; add its arm to
   `Node::apply` (recurse into operands).
2. `model/assets.rs`: add any `CanonicalAssets` std-ops impl the semantics need
   (e.g. `impl Div<i128>`), mirroring the sibling impl.
3. `reduce/mod.rs`: extend the `Arithmetic` trait (or relevant trait) and all its impls
   (`i128`, generic `Into<CanonicalAssets>`, `Expression`); add the new variant's arm to
   **all four** `Composite for BuiltInOp` methods — `components`, `try_map_components`,
   `reduce_self`, `reduce_nested`. Keep `Expression::None` absorbing unless semantics say
   otherwise; surface invalid operand combinations as `Error::InvalidBinaryOp`, never a panic.
4. Add reduce tests: happy path, interaction/precedence with the sibling op, error cases.
5. `cargo test -p tx3-tir` — including the backward-compat snapshot test.

### 2. lang/tx3 — grammar through lowering
1. `tx3.pest`: add the token rule and extend the relevant production
   (e.g. `data_infix = _{ data_add | data_sub | data_mul | data_div }`).
2. `ast.rs`: new node struct (lhs/rhs/span) + `target_type()`, enum variant, dispatch arm —
   clone the sibling.
3. `parsing.rs`: parse fn, Pratt registration (same `.op()` call as its precedence peers),
   `map_infix`/`map_prefix` arm, `span()` arm.
4. `analyzing.rs`: `impl Analyzable` (usually a structural clone) + both dispatch arms
   (`analyze`, `is_resolved`).
5. `lowering.rs`: `impl IntoLower` emitting the new `ir::BuiltInOp` variant + dispatch arm.
6. Add parsing tests: the bare form, precedence vs the adjacent looser tier, associativity
   vs its same-tier peer.
7. Build/test with the `[patch.crates-io]` override to local tir; then revert the patch.
8. Update the spec (`specs/v1beta0/`): lexical token list + any lexer gotchas (§3),
   grammar production + precedence table (§4 — same row as peers, not a new one), type
   system operand table + error semantics (§5). Remove any "no <feature>" exclusion
   language that the change obsoletes.

### 3. Sweep downstream consumers
Find every exhaustive match the new variant breaks — compile errors are the safety net,
so **build every consumer** with patches:
```bash
grep -rn "BuiltInOp::" registry tooling --include="*.rs"
grep -rn "DataExpr::" tooling --include="*.rs"
```
Known sites: `registry/backend/src/ast_to_svg.rs`, `tooling/tx3-lift` smoke test,
`tooling/tx3-lsp/src/visitor.rs`. Check `plugins/vscode-tx3` tmLanguage regexes (often
already cover the token). Build each with temporary patches; if an unrelated pre-existing
failure blocks a workspace build, scope to the affected package (`cargo test -p <pkg>`).
Revert all patches.

### 4. Docs and agent skills
- `docs/language/data.md`: operators table row, precedence list, gotcha callouts; drop
  stale exclusion sentences.
- `docs/language/assets.md` (if asset semantics): a worked example beside the sibling's.
- `plugins/tx3-skills/skills/tx3-language/`: `reference/expressions.md` table row and the
  `SKILL.md` operator summary line. Skills must teach the same semantics the spec defines
  (rounding, commutativity, error cases, gotchas).

### 5. Verify end-to-end
1. All affected workspaces compile and their tests pass (with patches, then reverted).
2. Backward-compat snapshot test in tir passes.
3. If `tx3-mcp` is available: `tx3_parse` shows the new AST node, `tx3_check` is clean,
   `tx3_lower`/`tx3_apply_args` show the TIR variant, and a constant expression folds while
   a parameterized one stays unreduced.

### 6. One branch + PR per modified submodule
For each modified submodule: `git checkout -b feat/<feature-name>`, commit, push,
`gh pr create`. Each dependent PR body should state the merge/release ordering
("merge after tx3-lang/tir #N releases"). Verify no `[patch.crates-io]` or `Cargo.lock`
churn is included in any commit.

### 7. Release lockstep (separate user go-ahead)
**(1)** merge + release `tx3-tir` to crates.io; **(2)** bump the `tx3-tir` dep and land
`tx3-lang`, `registry`, `tx3-lift`; **(3)** bump `tx3-lang` in `tx3-lsp` and other tooling;
**(4)** bump submodule pointers in the umbrella (use the `commit-umbrella` skill). Decide
the `trix.toml [toolchain]` min-version bump with the user.

## Decision Guidelines
- **Pin semantics before code.** For an operator: operand-type table (which combinations
  are valid and what they return), commutativity (e.g. `*` commutes over `Int * AnyAsset`;
  `/` does not), rounding/overflow mode (prefer native unchecked ops for consistency with
  the existing `+`/`-`/`*` convention), error cases (reduce-time `InvalidBinaryOp`, never
  panic), `None` absorption, and precedence/associativity (reuse an existing tier when the
  feature is a peer; new tiers need explicit justification).
- **Clone the cleanest sibling.** Don't design structure from scratch — grep for the most
  recently added comparable feature and mirror it at every layer. Divergences from the
  sibling are exactly the design decisions to surface to the user.
- **Scope ride-alongs explicitly.** Adjacent features (e.g. `%` next to `/`) are out of
  scope unless the user opts in — flag them at planning time.
- **Backward compat is non-negotiable** for TIR enums: append-last only. If a feature
  can't be expressed by appending, it's a schema-version conversation, not a quiet change.
- **Spec language hygiene:** new features often falsify old exclusion claims ("there is no
  division") — search the spec and docs for them.

## Safety Checks
- [ ] New TIR variant appended as the LAST enum entry; `test_decoding_is_backward_compatible` passes.
- [ ] All four `Composite for BuiltInOp` methods handle the new variant.
- [ ] Pratt registration shares the `.op(...)` call with its precedence peers (no accidental new tier).
- [ ] Grep sweep confirms no remaining non-exhaustive `BuiltInOp`/`DataExpr` match site, and every consumer workspace compiled against the patched deps.
- [ ] Every temporary `[patch.crates-io]` and `Cargo.lock` change reverted before committing.
- [ ] Spec, docs, and tx3-skills all updated and mutually consistent (same semantics, same gotchas).
- [ ] Error semantics tested (e.g. divide-by-zero) — reduce-time error, no panic.
- [ ] One PR per modified submodule, with dependency ordering noted in PR bodies.

## Error Handling
- **`unknown variant <X>` when decoding TIR** — a reader without the new variant met new
  TIR. Expected forward-incompat; gate via `trix.toml [toolchain]` min version.
- **Unrelated build failure in a consumer workspace** (e.g. a broken sibling binary) —
  scope to the package under test with `cargo test -p <pkg>`; note the pre-existing failure
  to the user, don't fix it in this change.
- **`git checkout Cargo.toml Cargo.lock` leaves files modified** — revert each path
  individually: `git checkout -- Cargo.toml && git checkout -- Cargo.lock`.
- **Operator parses at the wrong precedence** — the token got its own `.op(...)` line;
  merge it into the peer tier's call with `|`.
- **Backward-compat snapshot fails** — the variant was inserted mid-enum or an existing
  variant changed shape; move the new variant to the end and leave existing ones untouched.
