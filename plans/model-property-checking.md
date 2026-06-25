# Plan: `property` blocks + `trix prove` — prove properties of the Tx3 *model*

Status: **design proposal — not scheduled. Decisions converged in a design
session (2026-06-24); written for review before implementation.**
Scope: cross-cutting but additive. `lang/tx3` core (a new `property` top-level item
+ binders/goal clauses, parser, analyzer), a typed *invariant IR* shared with the
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
IR; the property language here is exactly that invariant language inside a
`property` block. [`account-model-fitness-evm-strawman.md`](./account-model-fitness-evm-strawman.md)
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
`property` blocks + `trix prove` make it a decision procedure that returns
counterexamples.

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
2. **The property language *is* the invariant language.** A `property` reuses the
   same Bool expression grammar as `rule`/`fn` bodies — no new operators. The only
   new surface is the `property` block (binders + optional hypotheses + one goal).
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
   `fn`s, and `property` goals all lower into one typed predicate IR.
5. **Proofs are profile-scoped.** Because `env` is frozen per profile, a property
   referencing `env.*` is proven against that profile's values — `trix prove
   --profile mainnet` — mirroring the profile-dependent-identity discipline.
6. **A verifier is a sibling of the compiler, not a backend that emits bytes.** It
   reuses the `Visitor`/`Node::apply` walk
   ([`../core/tir/crates/tx3-tir/src/lib.rs`](../core/tir/crates/tx3-tir/src/lib.rs),
   blanket impl in `compile.rs`) but returns a *verdict* (proved / refuted+model /
   unknown), so it implements its own `Verifier` trait, not `Compiler`.
7. **`property` blocks are spec artifacts, erased before lowering.** Like tests,
   they never reach TIR or codegen and never affect a policy hash.
8. **The surface is forward-compatible across scope by construction.** The verified
   *subject* is always a transaction (later, a trace); a rule is a *projection* of
   it, never a top-level subject — so widening to tx-level / protocol-level only
   *adds* clauses, never reinterprets existing ones. **Structure and acceptance are
   explicit predicates, not binder magic**: `invokes` ("this input runs that spend
   rule") and `accepted` ("every invocation accepts") are ordinary Bool predicates
   placed under `assume`/`assert`; the binder only *introduces names* (`tx`, input
   witnesses, fn vars). Putting `accepted` under `assume` vs `assert` is the
   soundness/completeness distinction. Future keywords (`trace`, `invariant`) are
   reserved from v1 so identifiers can't collide later.
9. **Inside a `property`, the transaction is observed by dot notation off the
   subject `tx`; inputs/outputs are namespaced records.** Context members are
   `tx.validity` / `tx.fee` / `tx.mint` (aggregate mint value); named parts live
   under `tx.inputs.<name>` / `tx.outputs.<name>`, so names can't collide with a
   context member. An input is a *record* projected explicitly — `.value`
   (AnyAsset), `.datum` (typed by its `datum_is`, then `.field`), `.redeemer` — so
   there is no value-vs-datum overload. A mint invocation's redeemer is
   `tx.mints.<Policy>.redeemer` (per-policy; distinct from the aggregate `tx.mint`).
   Bound input witnesses (`i in tx.inputs`) carry the same `.value`/`.datum`/
   `.redeemer` projections. Only binder-introduced names are bare; template *bodies*
   keep their own bare-name convention (`output { amount: locked - fees }`) — a
   property observes the transaction from *outside*, so it reaches in through `tx.`.
10. **ASCII proof-keyword surface; one binding per `for`.** Keep the Dafny/F\*/Why3
    idiom — `for` / `in` / `assume` / `assert` / `satisfiable` — not Unicode glyphs
    (they break Tx3's keyword grammar and burden tooling; the keywords already
    render the logic). The binder is **quantifier-neutral**: the *goal* supplies the
    quantifier (`assert` = ∀-valid, `satisfiable` = ∃), so `for` is correct where
    `forall` would mis-state the `satisfiable` case. Each `for` introduces exactly
    one binder (no comma-lists), keeping the grammar flat. Equivalence collapses
    into `assert a == b`, so there is no `equivalent` keyword.

## The language addition: `property` blocks

A `property` introduces names with **binders** (one `for …` each), optionally adds
hypotheses (`assume …`), and states one goal. The binder only *binds*: the subject
is a transaction (later a trace) plus any witnesses. **What the transaction does**
(`invokes`) and **whether it passes** (`accepted`) are ordinary predicates you put
under `assume`/`assert` (decision 8). Grammar (reuses the sibling plan's
`data_expr`):

```
property_def ::= "property" identifier "{" binding+ assume_stmt* goal ";" "}"
binding      ::= "for" binder ";"
binder       ::= "tx" ("=" tx_name)?          // the transaction (optionally a concrete template)
               | identifier "in" data_expr     // a witness from a collection (e.g.  i in tx.inputs)
               | identifier ":" type           // a free typed variable (fn-level)
               | "trace" "over" policy_name+   // FUTURE (reserved) — a sequence of txs
assume_stmt  ::= "assume" data_expr ";"
goal         ::= "satisfiable"                 // ∃ a binding satisfying the assumptions
               | "assert" data_expr            // ∀ such bindings: the expr holds
```

Two predicates extend `data_expr`, usable anywhere a Bool is (`assume`/`assert`):

```
  <input> invokes <Policy>.<purpose>   // this input executes that spend rule;
                                       //   when assumed, types its .datum / .redeemer
  tx invokes <Policy>.<purpose>        // tx mints / withdraws under that policy
  accepted           (= tx.accepted)   // every invocation in tx accepts
  <input>.accepted                     // the invocation on this input accepts
```

`accepted` is **scope-polymorphic** — bare `accepted` is the whole-tx conjunction;
`i.accepted` is one invocation. Its `assume`-vs-`assert` position is the
soundness/completeness distinction — the same primitives at every scope:

| Question | Form | Inclusion |
| --- | --- | --- |
| Every accepted tx satisfies `P` | `assume accepted; assert P;` | `V ⊆ Safe` (soundness) |
| This template is always accepted | `for tx = T; assert accepted;` | `Honest ⊆ V` (completeness) |
| The validator isn't a brick | `assume accepted; satisfiable;` | `V ≠ ∅` |
| Two definitions are equal | `assert a == b;` | refactor safety |

Everything is quantified over the binders' names, but the **binder is
quantifier-neutral** — the *goal* supplies the quantifier: `assert` is ∀-valid
(holds for all bindings), `satisfiable` is its ∃ dual (some binding exists). Two
goals, clean duals; equivalence is just `assert a == b`, so there's no separate
keyword (decision 10). A failing `assert` (or unsatisfiable `satisfiable`) yields a
counterexample. Concrete templates need no `invokes` — the toolchain derives the
invocation set from the template's `from:` / `mint` declarations; the abstract form
binds the input it constrains (`for tx; for i in tx.inputs;`).

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
// Model sanity — the spend rule is not a brick: some accepted tx satisfies it.
property vesting_satisfiable {
    for tx;
    for i in tx.inputs;
    assume i invokes Vesting.spend;
    assume i.accepted;
    satisfiable;
}

// Safety theorem (∀ accepted spend): never spends before the lock elapses.
// Derived from the rule and discharged by the solver.
property no_early_spend {
    for tx;
    for i in tx.inputs;
    assume i invokes Vesting.spend;
    assume i.accepted;
    assert tx.validity.since >= i.datum.lock_until;
}

// Completeness: every instantiation of `claim` is accepted by every script
// it invokes, all declared in the SAME model.  (Honest ⊆ V.)
property claim_always_accepted {
    for tx = claim;
    assert accepted;
}
```

### Run the prover

```text
$ trix prove --profile preview

  vesting_satisfiable     ✓ sat       witness: i.datum.lock_until = 0, tx.validity.since = 0
  no_early_spend          ✓ proved
  claim_always_accepted   ✗ refuted

    counterexample — a `claim` the model's own validator rejects:
        locked_utxo  ↦  a UTxO whose tx.inputs.locked.datum.lock_until = 1_000_001
        tx.validity.since = 1_000_000          (hard-coded by the template)
        ⇒ lock_elapsed(1_000_000, 1_000_001) = false

    `claim` can be applied to a still-locked UTxO; the resulting transaction
    is rejected. The template never constrains the locked UTxO's lock to have
    elapsed.

  2 proved · 1 refuted   (exit 1)
```

An example-based test would have passed here (pick any elapsed UTxO); the **proof**
found the design hole.

### Turn a failure into a hypothesis (define-a-hypothesis, prove-it loop)

```tx3
property claim_accepted_if_elapsed {
    for tx = claim;
    assume tx.inputs.locked.datum.lock_until <= 1_000_000;   // datum field of input `locked`
    assert accepted;
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

property refactor_preserves_meaning {
    for now: Int;
    for lock_until: Int;
    assert lock_elapsed(now, lock_until) == lock_elapsed_v2(now, lock_until);
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

property never_exceeds_cap {
    for tx;
    assume tx invokes CappedToken.mint;
    assume accepted;
    assert tx.mint <= env.max_supply;
}
```

`trix prove --profile mainnet` proves against mainnet's ceiling.

### Tx-level scope is the same surface, widened (not new syntax)

A transaction that invokes more than one script is just a subject with more than
one invocation — `accepted` conjoins them, and whole-transaction properties read
the shared `tx.*`. No new keyword; the single-script properties above are unchanged.

```tx3
tx claim_with_receipt(locked_utxo: UtxoRef) {
    input locked { ref: locked_utxo, from: Vesting,
                   datum_is: VestingDatum, redeemer: VestingRedeemer { note: "" } }
    mint        { amount: Receipt(1), redeemer: MintRedeemer { amount: 1 } }
    output      { to: Claimer, amount: locked - fees }
    validity    { since_slot: 1_000_000 }
}

property receipt_matches_claim {
    for tx = claim_with_receipt;     // invokes Vesting.spend AND Receipt.mint
    assume accepted;                 // same keyword, now conjoins BOTH scripts
    assert tx.mint == Receipt(1);    // a whole-transaction property
}
```

Cross-cutting *arithmetic* over the input/output sets (`sum(tx.outputs …)`,
`for all o in tx.outputs`) needs the deferred aggregate bindings — added later as
new in-scope vocabulary, breaking nothing (Phase 3).

### Surfaces

- `trix prove [--profile P] [--property NAME]` — primary CLI; non-zero exit on any
  refutation (CI-ready). Optionally a `prove` phase inside `trix test`.
- `tx3 prove` and an MCP `tx3_prove` tool (sibling to `tx3_check`) for the
  editor/agent loop — returns proved/refuted + counterexample as JSON.

## How it works

1. **`property` grammar + AST + analysis.** New top-level item alongside
   `tx`/`policy`/`fn`. The analyzer resolves each `for` binder (a `tx = template`,
   `tx`, an input witness `i in tx.inputs`, or a typed var), resolves the
   `invokes`/`accepted` predicates against the script-context schema (typing an
   input's `.datum`/`.redeemer` once it's known to invoke a given rule, per
   decision 6), and types `assume`/`assert`. For a concrete template the invocation
   set and `tx.inputs.<name>` / `tx.outputs.<name>` are derived from the template
   (decision 9); `accepted` lowers to the conjunction of those invocation
   predicates. Reserved keywords (`trace`, `invariant`) are claimed now. Erased
   before lowering to TIR. *(Files: `tx3.pest`, `ast.rs`, `parsing.rs`,
   `analyzing.rs`.)*
2. **Typed invariant IR.** The shared substrate (decision 4); rules, Bool `fn`s,
   and `property` goals lower into it carrying node types.
3. **`Verifier` + `SmtEmitter: Visitor`.** Translate the typed IR to SMT-LIB,
   reusing the `Visitor` walk the way `ParamSubstituter`
   ([`lowering.rs`](../lang/tx3/crates/tx3-lang/src/lowering.rs)) reuses it.
   Theories: `Int` (LIA; NIA only when `*`/`/` apply to two unknowns), `Bytes` →
   sequences, `AnyAsset` → `(Array AssetClass Int)` with finite support and the
   guarded `≥` from `contains_total`.
4. **Template symbolic evaluator.** For a `tx = template` subject, derive the
   constraint set from the template's TIR field expressions; free symbols + types
   come from `Tx::params()`, structure via `Composite::components()`
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
  (`property` block, per-`for` binders + input witnesses, the `invokes`/`accepted`
  predicates, `assume`/goal clauses, reserved keywords),
  [`src/ast.rs`](../lang/tx3/crates/tx3-lang/src/ast.rs) (`PropertyDef` node),
  `src/parsing.rs`, `src/analyzing.rs` (binder + witness resolution, `invokes`/
  `accepted` predicate typing, `accepted` = conjunction of invocations, decision-6 cross-check).
- **IR** — the typed invariant IR shared with the sibling plan; `property`/rule/fn
  lowering into it.
- **Prover** — new `tx3-prove` crate: `Verifier` trait, `SmtEmitter: Visitor`,
  template symbolic evaluator, solver driver, counterexample mapper. Reuses
  `reduce/mod.rs` (reference semantics) and `model/assets.rs` (value theory).
- **trix** — `trix prove` command (+ optional `trix test` phase), `--profile`
  scoping, CI exit codes.
- **MCP** — `tx3_prove` tool in the tx3 MCP server.
- **Spec** — a short section documenting `property` semantics and the model-vs-
  enforcement caveat (decision 1).

## Phased delivery

| Phase | Deliverable | New syntax (additive over the prior row) | Effort |
| --- | --- | --- | --- |
| 0 | `reduce()`-agreement proptest + `AnyAsset` value-algebra theory (trust anchor) | none | low — start now |
| 1 | Typed invariant IR + `SmtEmitter`; single-input soundness (`for tx; for i in tx.inputs;` + `assume i invokes R` + `assume i.accepted` + `assert`/`satisfiable`) + counterexamples | `property`/`for`/`in`/`invokes`/`accepted`/`assume`/`assert`/`satisfiable` | medium |
| 2 | Concrete-template completeness (`for tx = T` + `assert accepted`); `trix prove` CI + `tx3_prove` MCP | `for tx = …` | medium |
| 3 | **Tx-level**: multiple bound inputs / `invokes` assumptions + aggregate/quantifier bindings over input/output sets (`sum`, `for all o in tx.outputs`) | aggregate vocabulary (`sum`, `for all`) | high — needs the sibling's deferred input/output bindings |
| 4 (post-v1) | **Protocol-level**: the `trace` subject + `invariant` goal (inductive invariants over tx sequences) | `trace`/`invariant` | high |

Every row only *adds* clauses to the prior surface; none reinterprets earlier syntax
(decision 8), and the phase-3/4 keywords are reserved in phase 1.

**First move: Phase 0 + Phase 1's `satisfiable` property** — Phase 0 needs no
language surface, and the vacuity check alone catches the worst bug class (a
validator that can never pass → permanently locked funds), which examples miss
entirely.

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
  `lock_until = 1_000_001` counterexample; adding `assume
  tx.inputs.locked.datum.lock_until <= 1_000_000` makes `claim_accepted_if_elapsed`
  prove.
- **Refactor:** `refactor_preserves_meaning` proves; mangle `lock_elapsed_v2` → it
  refutes with a concrete `(now, lock_until)` witness.
- **Real protocol:** run `trix prove` against a vesting/treasury shape under
  [`../protocols/`](../protocols/) and confirm the value/time theorems match the
  hand-written validator's intent.

## Open questions (for review)

- **Where properties live.** In `.tx3` source (co-located, single source of truth)
  vs. a separate `proofs.tx3` / `proofs.toml` like the test harness. Default
  proposed: co-located, since the property language *is* the invariant language.
- **Bounded vs idealized integers.** `BitVec 128` (faithful to `reduce()`'s `i128`)
  vs mathematical `Int` (cleaner, but diverges near overflow). Decision 3 says pick
  one explicitly; which?
- **Solver bundling.** Shell out to a system `z3` (delegation model) vs. vendoring a
  linked solver crate for hermetic CI.
- **Deferred-scope timing.** Tx-level (Phase 3: multi-script subjects + aggregate
  bindings) and protocol-level (Phase 4: the `trace` subject) both depend on the
  sibling's deferred input/output bindings. Confirm they stay post-v1 — the surface
  already reserves their keywords (decision 8) so they land additively, no rework.
