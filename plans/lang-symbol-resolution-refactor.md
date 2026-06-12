# Plan: refactor symbol resolution to shared handles

Status: **open / not started** — quality refactor, no behavioural change intended
Scope: `lang/tx3` (`crates/tx3-lang/src/{ast,analyzing,lowering}.rs`)
Origin: follow-up from tx3-lang/tx3#311 (user-defined functions). The fn→fn
fix there (`Program::analyze` fixed-point loop) is a minimal patch *inside*
the current symbol design; this plan removes the design pressure that made
the patch necessary.

## Context

`analyzing::Program::analyze` is more complex than it should be. Functions are
registered into the program scope **before** they are analyzed, then — because
the registered entries are stale — they are re-registered into a fresh child
scope after analysis (so `tx` bodies resolve the analyzed versions), and #311
added a further fixed-point loop so that **function-to-function** calls also
embed analyzed callees. Reviewers reasonably ask: why not register functions
once at the root scope and resolve via parent traversal?

The answer is not lookup — parent traversal already works. The complexity is a
consequence of how symbols are *stored*:

- `Symbol` (`ast.rs`) is a **by-value** enum: each variant owns a
  `Box<Definition>` (e.g. `FunctionDef(Box<FnDef>)`).
- `Scope::track_*` inserts a **clone** of the definition
  (`Symbol::FunctionDef(Box::new(fn_def.clone()))`), and `Scope::resolve`
  hands out **another clone** (`symbol.clone()`).
- `Identifier::analyze` bakes that clone into the AST node:
  `self.symbol = parent.resolve(&self.value)`.
- Analysis is an **in-place mutating pass**, and lowering **inlines** a
  function by walking the callee's analyzed body
  (`fn_def.body.result.into_lower`), which requires the callee's *inner*
  identifiers to already be resolved.

So a function symbol is a snapshot of a thing that is still mutating. A
snapshot captured before analysis is wrong, and the only way to "update" a
by-value snapshot is to take a new one and re-insert it — which is exactly the
re-registration / fixed-point dance. Leaf symbols (`ParamVar`, `EnvVar`,
`Fees`, `PartyDef`…) never need this because they are immutable facts with no
sub-nodes awaiting analysis; the problem is specific to definitions that
contain analyzable bodies (today: `FnDef`).

`Identifier.symbol` and `FnDef.scope` are both `#[serde(skip)]`, so symbol
representation is **analysis-only state** — changing it does not touch the
`.ast`/`.tir` golden formats.

## Goal

Register each definition **once** at the scope where it belongs and have all
resolvers and call sites observe the *same, eventually-analyzed* definition,
so that:

- `Program::analyze` drops the post-analysis re-registration and the
  fixed-point loop (single pass, correct to any call depth);
- lowering reads an always-current callee instead of a frozen copy;
- behaviour is unchanged — same diagnostics, same lowered TIR, all existing
  golden tests pass without regeneration.

## Approach (recommended): shared handles in `Symbol`

Change the definition-bearing `Symbol` variants from owning a `Box<Def>` to
holding a shared, interior-mutable handle — `Rc<RefCell<Def>>` (or a copyable
`DefId` index into a central `Vec<Def>` owned by the `Program`/analysis
context). Then:

1. A definition is registered once; `resolve` clones the **handle**, not the
   definition, so every reference points at one object.
2. When the definition is analyzed (in place, through the handle), every
   prior and future resolution sees the analyzed form. Forward references and
   fn→fn calls resolve naturally via parent traversal with no ordering
   constraint.
3. Lowering dereferences the handle, always observing the analyzed body.

Between `Rc<RefCell<_>>` and the `DefId`-arena variant, prefer whichever keeps
borrow scopes simplest:

- **`Rc<RefCell<FnDef>>`** is the smaller diff but introduces runtime borrow
  discipline (no live `borrow()` across an `analyze`/`into_lower` that might
  re-borrow the same def — relevant precisely for recursion, which is
  disallowed, but still a panic risk to design around).
- **`DefId` + arena** avoids `RefCell` aliasing hazards (resolve returns a
  `Copy` id; consumers look up the arena when they need the def) at the cost
  of threading the arena/`Program` through analysis and lowering — note the
  lowering `Context` currently carries no `Program` reference, so this leg has
  the same lifetime-threading cost flagged in #311.

Decide between them in a short spike before committing to the full change.

### Scope of the change (seams)

- `ast.rs` — `Symbol` enum definition and the `as_*` accessors
  (`as_fn_def`, `as_type_def`, `as_policy_def`, …). ~12 sites.
- `analyzing.rs` — `Scope::{track_*, resolve}`, `Identifier::analyze`,
  `Program::analyze` (the block this plan targets), and every `match`
  on `Symbol::*`. ~34 sites.
- `lowering.rs` — `Identifier::into_lower`, `FnCall::into_lower`, and the
  other `Symbol::*` consumers. ~10 sites.

Most edits are mechanical (`x.as_ref()` → `x.borrow()` / arena lookup). The
substantive edits are confined to `Scope` and `Program::analyze`.

Start by migrating **only `FunctionDef`** to the shared handle (the one
variant that actually needs it) to keep the first PR bounded; the other
definition variants can follow the same pattern in a second pass if it proves
clean, or stay by-value if they never grow analyzable bodies.

## Risks / watch-outs

- **Borrow panics** (if `Rc<RefCell>`): never hold a `borrow()`/`borrow_mut()`
  across a recursive call into the same def. The no-recursion rule (spec §6.2)
  helps but is not yet *enforced* by the analyzer — pair this work with cycle
  detection, or the refactor can turn the current stack-overflow-on-recursion
  into a `RefCell` double-borrow panic.
- **Behaviour parity**: this is a pure refactor. Treat any change to a
  `.ast`/`.tir` golden, or to a diagnostic, as a regression to investigate —
  not a snapshot to regenerate.
- **Scope identity**: `FnDef.scope: Option<Rc<Scope>>` already creates
  `Rc` cycles risk if a def's handle is reachable from its own scope; keep the
  handle out of the scope graph it points into.

## Verification

- `cd lang/tx3 && cargo test -p tx3-lang` — all 161+ parsing/lowering golden
  tests pass **without** regenerating any golden.
- Re-confirm the #311 regression cases lower correctly: `functions`,
  `nested_functions` (depth-2 fn→fn), `tip_slot`, `posix_time`.
- Diff `Program::analyze` before/after: the re-registration block and the
  fixed-point loop should be gone, replaced by a single registration pass.
- Add a fn→fn→fn (depth-3) example to prove single-pass resolution scales with
  no loop.
- `git diff` the lowered TIR of a representative protocol (e.g. via
  `tx3-skills tx3:inspect`) to confirm byte-identical output.
