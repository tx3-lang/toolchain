# Plan: `check` blocks + `trix prove` — prove properties of the Tx3 *model*

Status: **design proposal — not scheduled. Decisions converged in a design
session (2026-06-24); written for review before implementation.**
Scope: cross-cutting but additive. `lang/tx3` core (a new `check` top-level item +
binders/goal clauses, parser, analyzer), a typed *invariant IR* shared with the
sibling policy plan, a new `tx3-prove` crate (SMT emitter + solver driver +
counterexample mapper), a `trix prove` command, and a `tx3_prove` MCP tool. The
SMT translation reuses the existing `reduce` engine as reference semantics and the
`AnyAsset` value model; no chain backend work.
Origin: design discussion (2026-06-24) on applying formal methods to Tx3. The
explicit goal set by review: **prove properties of the Tx3 model — the declared
templates and invariants — not the derived enforcement layer (the generated
validator scripts).**
Related: [`policy-invariant-script-generation.md`](./policy-invariant-script-generation.md)
— this plan *consumes* its language additions (comparison/boolean operators,
multi-statement `fn`, `rule`-block `policy`; decisions 3–5) and its typed invariant
IR; the property language here is exactly that invariant language under a `check`
binder. [`account-model-fitness-evm-strawman.md`](./account-model-fitness-evm-strawman.md)
— shares the boolean/comparison operators and a `require`/assertion sensibility.
[`tx3-protocol-limitations.md`](./tx3-protocol-limitations.md) — the bug classes
(`*`/`/` pre-computation leaks, datum access) that property proofs would catch
earlier. Language spec under [`../lang/tx3/specs/v1beta0/`](../lang/tx3/specs/v1beta0/)
(§5 type system, §7.13 functions, §7.14 cross-block constraints); the de-facto
operational semantics in [`../core/tir/crates/tx3-tir/src/reduce/mod.rs`](../core/tir/crates/tx3-tir/src/reduce/mod.rs).

## Context

The sibling [`policy-invariant-script-generation.md`](./policy-invariant-script-generation.md)
reverses Tx3's workflow: instead of pointing a `policy` at an opaque content-
addressed hash, it declares the validator's logic **in source** as a typed
`rule`/`fn` predicate. The moment invariants stop being bytecode and become a
typed predicate, they become a *logical object* — something a tool can refute or
prove about. That is the precondition this plan builds on.

The model a `.tx3` program declares is two things, both given meaning by the
existing `reduce` engine:

- **`tx` templates** — parametric transaction *shapes*; each field is an expression
  over the template's params (e.g. `output.amount = locked - fees` lowers to a
  symbolic `Sub`). These are the moves an honest client can make.
- **`policy`/`rule`/`fn` invariants** — closed (per-profile, `env` frozen) Bool
  expressions over rule params + script context. These are what the chain accepts.

**Goal:** prove theorems and check hypotheses about *those declared objects*, at
the source/IR level, with `reduce()` as the reference semantics — catching design
bugs (bricked validators, templates that resolve to rejected transactions, broken
refactors) with proofs rather than examples. The plan's existing **"duality test
oracle"** (happy-path passes, mutations fail) is the example-based shadow of this;
`check` + `trix prove` makes it a decision procedure that returns counterexamples.

**Explicitly out of scope: the enforcement layer.** We prove the model under
`reduce()` semantics; we do *not* prove the generated UPLC realizes it. That keeps
the hard items off the critical path — no codegen translation-validation, and the
`find_script_for_hash` `todo!()`
([`../lang/tx3/crates/tx3-cardano/src/compile/mod.rs`](../lang/tx3/crates/tx3-cardano/src/compile/mod.rs))
is **not** a blocker here, because the template↔rule link this plan needs is a
name/type resolution at the analyzer layer (the sibling's decision 6 already
cross-checks a template's `datum_is` against the matching rule's parameter), not a
hash→script lookup.

## Decisions

1. **Prove the model, not the artifact.** The verified object is the typed
   invariant IR under `reduce()` semantics. Faithfulness of IR→UPLC codegen is a
   separate concern, deliberately excluded. Docs must say so, so a green
   `trix prove` is not over-read as an on-chain guarantee.
2. **The property language *is* the invariant language.** A `check` reuses the same
   Bool expression grammar as `rule`/`fn` bodies — no new operators. The only new
   surface is the `check` block (binder + optional hypotheses + one goal).
3. **`reduce()` is the reference semantics; agreement is mechanically tested.** The
   SMT translation must agree with
   [`reduce/mod.rs`](../core/tir/crates/tx3-tir/src/reduce/mod.rs) on every closed
   expression. This is pinned by a differential proptest *before* any proof is
   trusted (see §How it works, step 5). Three known divergences are modelled, not
   assumed away: truncating `/` vs SMT floor-`div`; bounded `i128` vs unbounded
   `Int`; the non-negativity-guarded asset `≥` that `contains_total` implements
   ([`../core/tir/crates/tx3-tir/src/model/assets.rs`](../core/tir/crates/tx3-tir/src/model/assets.rs)).
4. **The proof IR is a typed IR fed from the analyzer — the same one the sibling
   plan calls for.** TIR erases node types (`Property` is a bare index;
   [`v1beta0.rs`](../core/tir/crates/tx3-tir/src/model/v1beta0.rs)); static `Type`
   lives only on the AST
   ([`analyzing.rs`](../lang/tx3/crates/tx3-lang/src/analyzing.rs)). Rules, Bool
   `fn`s, and `check` goals all lower into one typed predicate IR.
5. **Proofs are profile-scoped.** Because `env` is frozen per profile, a property
   referencing `env.*` is proven against that profile's values — `trix prove
   --profile mainnet` — mirroring the profile-dependent-identity discipline.
6. **A verifier is a sibling of the compiler, not a backend that emits bytes.** It
   reuses the `Visitor`/`Node::apply` walk
   ([`../core/tir/crates/tx3-tir/src/lib.rs`](../core/tir/crates/tx3-tir/src/lib.rs),
   blanket impl in `compile.rs`) but returns a *verdict* (proved / refuted+model /
   unknown), so it implements its own `Verifier` trait, not `Compiler`.
7. **`check` blocks are spec artifacts, erased before lowering.** Like tests, they
   never reach TIR or codegen and never affect a policy hash.

## The language addition: `check` blocks

A `check` binds a *universe* (`for …`), optionally adds hypotheses (`assume …`),
and states exactly one goal. Grammar (reuses the sibling plan's `data_expr` and
statement forms):

```
check_def    ::= "check" identifier "{" binder ";" assume_stmt* goal ";" "}"
binder       ::= "for" purpose_name parameter_binding "in" policy_name   // a rule's universe
              |  "for" tx_name                                           // a template's universe
              |  "for_all" param_list                                    // bare fn params
assume_stmt  ::= "assume" data_expr ";"
goal         ::= "satisfiable"
              |  "assert" data_expr
              |  "accepted_by" policy_name "." purpose_name
              |  "equivalent" data_expr "," data_expr
```

Semantics (everything universally quantified over the bound variables; a failing
proof yields a counterexample assignment):

| Goal | Meaning | Inclusion bound |
| --- | --- | --- |
| `satisfiable` | the bound rule predicate is SAT (not a brick) | `V ≠ ∅` |
| `assert P` | every tx accepted by the bound rule satisfies `P` | `V ⇒ P` (soundness, `V ⊆ Safe`) |
| `accepted_by Pol.rule` | every instantiation of the bound template satisfies the rule | `template ⇒ V` (completeness, `Honest ⊆ V`) |
| `equivalent a, b` | `a` and `b` are equal for all bindings | refactor safety |

`for <rule> in <Policy>` assumes the rule predicate (we reason about *accepted*
txs) and binds the rule's params + ambient script context. `for <tx>` assumes the
template's symbolic field constraints and binds its params. `assume` adds
hypotheses (preconditions) to the assumption set.

## Developer experience

### Write the protocol (sibling-plan syntax)

```tx3
party Claimer;

type VestingDatum    { beneficiary: Bytes, lock_until: Int }
type VestingRedeemer { note: Bytes }

fn lock_elapsed(now: Int, lock_until: Int) -> Bool {
    now >= lock_until
}

policy Vesting {
    rule spend(datum: VestingDatum, redeemer: VestingRedeemer) {
        require lock_elapsed(tx.validity.since, datum.lock_until);
    }
}

tx claim(locked_utxo: UtxoRef) {
    input locked {
        ref: locked_utxo,
        from: Vesting,
        datum_is: VestingDatum,
        redeemer: VestingRedeemer { note: "" },
    }
    output { to: Claimer, amount: locked - fees }
    validity { since_slot: 1_000_000 }
}
```

### State properties — same expression language, no new operators

```tx3
// Model sanity — the validator is not a brick: some tx satisfies it.
check vesting_satisfiable {
    for spend(datum, redeemer) in Vesting;
    satisfiable;
}

// Safety theorem (∀ accepted tx): never spends before the lock elapses.
// Derived from the rule and discharged by the solver.
check no_early_spend {
    for spend(datum, redeemer) in Vesting;
    assert tx.validity.since >= datum.lock_until;
}

// Completeness: every instantiation of `claim` is accepted by the rule
// declared in the SAME model.  (Honest ⊆ V.)
check claim_always_accepted {
    for claim;
    accepted_by Vesting.spend;
}
```

### Run the prover

```text
$ trix prove --profile preview

  vesting_satisfiable     ✓ sat       witness: datum.lock_until = 0, tx.validity.since = 0
  no_early_spend          ✓ proved
  claim_always_accepted   ✗ refuted

    counterexample — a `claim` the model's own validator rejects:
        locked_utxo  ↦  a UTxO whose datum.lock_until = 1_000_001
        tx.validity.since = 1_000_000          (hard-coded by the template)
        ⇒ lock_elapsed(1_000_000, 1_000_001) = false

    `claim` can be applied to a still-locked UTxO; the resulting transaction
    is rejected. The template never constrains the locked UTxO's lock to have
    elapsed.

  2 proved · 1 refuted   (exit 1)
```

An example-based test would have passed here (pick any elapsed UTxO); the **proof**
found the design hole.

### Turn a failure into a hypothesis (define-a-hypothesis, check-it loop)

```tx3
check claim_accepted_if_elapsed {
    for claim;
    assume locked.lock_until <= 1_000_000;   // the precondition the caller must hold
    accepted_by Vesting.spend;
}
```

```text
$ trix prove
  claim_accepted_if_elapsed   ✓ proved
```

The dev now knows precisely what the off-chain caller must guarantee (or that
`claim` should take `since_slot` as a param `>= lock_until`). The prover became a
design tool.

### Prove a refactor safe

```tx3
fn lock_elapsed_v2(now: Int, lock_until: Int) -> Bool {
    not (now < lock_until)
}

check refactor_preserves_meaning {
    for_all now: Int, lock_until: Int;
    equivalent lock_elapsed(now, lock_until), lock_elapsed_v2(now, lock_until);
}
```

```text
$ trix prove
  refactor_preserves_meaning   ✓ proved      (equal for all inputs)
```

Change one definition incorrectly and you get a concrete `(now, lock_until)`
counterexample, not a silent regression.

### `env`-frozen invariants are profile-scoped

```tx3
type MintRedeemer { amount: Int }
fn capped(minted: AnyAsset, ceiling: AnyAsset) -> Bool { minted <= ceiling }

policy CappedToken {
    rule mint(redeemer: MintRedeemer) { require capped(tx.mint, env.max_supply); }
}

check never_exceeds_cap {
    for mint(redeemer) in CappedToken;
    assert tx.mint <= env.max_supply;
}
```

`trix prove --profile mainnet` proves against mainnet's ceiling.

### Surfaces

- `trix prove [--profile P] [--check NAME]` — primary CLI; non-zero exit on any
  refutation (CI-ready). Optionally a `prove` phase inside `trix test`.
- `tx3 prove` and an MCP `tx3_prove` tool (sibling to `tx3_check`) for the
  editor/agent loop — returns proved/refuted + counterexample as JSON.

## How it works

1. **`check` grammar + AST + analysis.** New top-level item alongside
   `tx`/`policy`/`fn`. The analyzer types each goal/`assume` against the referenced
   rule/fn signature, resolves `Policy.rule` and `tx` names, and applies the
   sibling's decision-6 template↔rule param cross-check. Erased before lowering to
   TIR. *(Files: `tx3.pest`, `ast.rs`, `parsing.rs`, `analyzing.rs`.)*
2. **Typed invariant IR.** The shared substrate (decision 4); rules, Bool `fn`s,
   and `check` goals lower into it carrying node types.
3. **`Verifier` + `SmtEmitter: Visitor`.** Translate the typed IR to SMT-LIB,
   reusing the `Visitor` walk the way `ParamSubstituter`
   ([`lowering.rs`](../lang/tx3/crates/tx3-lang/src/lowering.rs)) reuses it.
   Theories: `Int` (LIA; NIA only when `*`/`/` apply to two unknowns), `Bytes` →
   sequences, `AnyAsset` → `(Array AssetClass Int)` with finite support and the
   guarded `≥` from `contains_total`.
4. **Template symbolic evaluator.** For `for <tx>`, derive the constraint set from
   the template's TIR field expressions; free symbols + types come from
   `Tx::params()`, structure via `Composite::components()`
   ([`reduce/mod.rs`](../core/tir/crates/tx3-tir/src/reduce/mod.rs)).
5. **`reduce()`-agreement harness (trust anchor).** Clone the proptest harness in
   [`model/assets.rs`](../core/tir/crates/tx3-tir/src/model/assets.rs) to assert
   `smt_eval(translate(e)) == reduce(e)` on random closed expressions (and
   undefined-exactly-when-`reduce`-errors). Pins the three traps in decision 3
   before any proof is trusted. **Needs no new language surface — build first.**
6. **Counterexample mapper.** Render an SMT model back into concrete Tx3 values
   (param bindings, datum/redeemer fields, validity slots) in source terms.
7. **Solver driver.** Shell out to `z3` (matches trix's subprocess-delegation
   model, like Aiken) or link a crate; pin the solver version into the verdict for
   reproducibility.

## Files touched (when implemented)

- **Front end** — [`../lang/tx3/crates/tx3-lang/src/tx3.pest`](../lang/tx3/crates/tx3-lang/src/tx3.pest)
  (`check` block, binders, `assume`/goal clauses),
  [`src/ast.rs`](../lang/tx3/crates/tx3-lang/src/ast.rs) (`CheckDef` node),
  `src/parsing.rs`, `src/analyzing.rs` (goal/`assume` typing, `Policy.rule` + `tx`
  resolution, decision-6 cross-check reuse).
- **IR** — the typed invariant IR shared with the sibling plan; `check`/rule/fn
  lowering into it.
- **Prover** — new `tx3-prove` crate: `Verifier` trait, `SmtEmitter: Visitor`,
  template symbolic evaluator, solver driver, counterexample mapper. Reuses
  `reduce/mod.rs` (reference semantics) and `model/assets.rs` (value theory).
- **trix** — `trix prove` command (+ optional `trix test` phase), `--profile`
  scoping, CI exit codes.
- **MCP** — `tx3_prove` tool in the tx3 MCP server.
- **Spec** — a short section documenting `check` semantics and the model-vs-
  enforcement caveat (decision 1).

## Phased delivery

| Phase | Deliverable | New syntax | Effort |
| --- | --- | --- | --- |
| 0 | `reduce()`-agreement proptest + `AnyAsset` value-algebra theory (trust anchor) | none | low — start now |
| 1 | Typed invariant IR + `SmtEmitter`; `check … satisfiable` / `assert` over one rule (vacuity + safety theorems) + counterexamples | `check`/`for…in`/`assert`/`satisfiable` | medium |
| 2 | `for <tx>` symbolic eval + `accepted_by` (completeness) + `assume` | `for <tx>`/`accepted_by`/`assume` | medium-high |
| 3 | `equivalent` + `for_all`; `trix prove` CI integration; `tx3_prove` MCP | `equivalent`/`for_all` | medium |
| 4 (post-v1) | Protocol-level temporal properties over tx *sequences* (transition-system / inductive invariants) | richer binders | high — needs the sibling's deferred input/output bindings |

**First move: Phase 0 + Phase 1's `satisfiable` check** — Phase 0 needs no language
surface, and the vacuity check alone catches the worst bug class (a validator that
can never pass → permanently locked funds), which examples miss entirely.

## Out of scope / limits

- **The enforcement layer** (decision 1) — proofs bind the chain only insofar as
  codegen faithfully realizes the IR; that faithfulness is not proven here.
- **Nonlinear arithmetic.** `*`/`/` on two unknowns → NIA, undecidable; the prover
  is best-effort and reports `unknown` honestly, never as "proved."
- **Dynamic aggregates.** The sibling's deferred input/output bindings mean
  template constraints can't sum over dynamic lists yet; properties stay
  local/per-purpose until those land (gates Phase 4).

## Verification (when implemented)

- **Phase 0 self-check:** the cloned `model/assets.rs` proptest passes with the SMT
  encoder wired in and *surfaces* the div-truncation, `i128`-overflow, and
  guarded-`contains_total` divergences.
- **Vacuity:** a contradictory rule (`require a >= b; require a < b;`) →
  `satisfiable` reports refuted (brick).
- **Safety theorem:** `no_early_spend` proves; delete the rule's `require` → it
  refutes with a pre-lock counterexample.
- **Completeness + hypothesis loop:** `claim_always_accepted` refutes with the
  `lock_until = 1_000_001` counterexample; adding `assume locked.lock_until <=
  1_000_000` makes `claim_accepted_if_elapsed` prove.
- **Refactor:** `refactor_preserves_meaning` proves; mangle `lock_elapsed_v2` → it
  refutes with a concrete `(now, lock_until)` witness.
- **Real protocol:** run `trix prove` against a vesting/treasury shape under
  [`../protocols/`](../protocols/) and confirm the value/time theorems match the
  hand-written validator's intent.

## Open questions (for review)

- **Where checks live.** In `.tx3` source (co-located, single source of truth) vs.
  a separate `proofs.tx3` / `proofs.toml` like the test harness. Default proposed:
  co-located, since the property language *is* the invariant language.
- **Bounded vs idealized integers.** `BitVec 128` (faithful to `reduce()`'s `i128`)
  vs mathematical `Int` (cleaner, but diverges near overflow). Decision 3 says pick
  one explicitly; which?
- **Solver bundling.** Shell out to a system `z3` (delegation model) vs. vendoring a
  linked solver crate for hermetic CI.
- **Temporal tier.** Whether any Phase-4 protocol-level (sequence) properties are
  wanted in the first cut, or strictly deferred until the deferred input/output
  bindings exist.
