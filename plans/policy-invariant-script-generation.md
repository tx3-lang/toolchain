# Plan: declare invariants in `policy`, generate validator scripts

Status: **design proposal — not scheduled. Decisions converged in a design
session; written for review before implementation.**
Scope: cross-cutting. `lang/tx3` core (new operators, multi-statement `fn`,
`rule`-block `policy` form), a new chain-agnostic *invariant IR* alongside
`core/tir`, the `tx3-cardano` script-generation backend, and a `trix` build
step. The enforcing backends' compilers are out of scope for v1.
Origin: design discussion (2026-06-24) on reversing Tx3's workflow — instead of
*referencing* externally-compiled scripts by content address, declare the
invariants *inside* the IDL and *generate* the scripts from them.
Related: [`tx3-protocol-limitations.md`](./tx3-protocol-limitations.md) — this
closes "tx3 cannot apply parameters to a script template";
[`account-model-fitness-evm-strawman.md`](./account-model-fitness-evm-strawman.md)
— a sibling language-design strawman (the operators it wants overlap with the
ones here); the language spec under
[`../lang/tx3/specs/v1beta0/`](../lang/tx3/specs/v1beta0/) (esp. §4 grammar,
§5 type system, §7 transaction semantics, §8 `cardano::` extensions); TII as
"OpenAPI for transactions" ([`../core/tii/README.md`](../core/tii/README.md)).

## Context

Tx3 is an IDL for UTxO protocols, today **off-chain-first**: a `tx` template
fixes a transaction's *shape*, and all invariant validation is assumed to live
in a content-addressed script declared elsewhere. The `policy` block reflects
this — it is something you *point at* by identity:

```tx3
policy P = 0xABCD…;                     // by hash literal  (PolicyValue::Assign)
policy P { hash: …, script: …, ref: … } // by hash / inline bytes / ref UTxO
```

(specs §4.2.4 / §7.13.4;
[`../lang/tx3/crates/tx3-lang/src/ast.rs`](../lang/tx3/crates/tx3-lang/src/ast.rs)
`PolicyDef`/`PolicyValue`; lowered to `core/tir` `PolicyExpr { name, hash,
script }`.)

The IDL has no way to declare the *invariants themselves*. This plan reverses the
workflow: author the spending/minting conditions in Tx3, and have the toolchain
**generate** the validator script — making the hash / script address a *derived
output* of compilation rather than a supplied constant.

**Outcome:** one Tx3 source of truth describing both the transaction shapes
(off-chain) and the invariants the chain enforces (on-chain), from which both
client bindings and validator scripts are generated. The existing by-hash /
by-ref `policy` forms coexist unchanged, for logic Tx3 won't express.

## Decisions

1. **Invariants are declared directly.** The policy declares the validation
   logic; Tx3 generates the script from it. No intermediate "parametric
   reference" stage.
2. **Policies are parameterised *only at compile time, via `env`*.** No
   per-invoke policy arguments. A policy's logic may reference `env` values;
   those are bound per build/profile and frozen into the generated script. This
   makes generation a pure **build-time** step with reproducible,
   per-profile-stable hashes, and leaves the runtime/resolve path untouched.
3. **Comparison + boolean operators become core language** (not a special
   predicate position). `==` `!=` `<` `<=` `>` `>=` produce `Bool`; `&&` `||`
   (infix) and `not` (prefix) combine `Bool`s. `!` stays arithmetic negation
   (§5.5.1); `not` is the new boolean negation — purely additive.
4. **Logic lives in Bool functions; the policy wraps named `rule` blocks.**
   Reusable logic is ordinary `fn`s with unrestricted typed params returning
   `Bool`; bodies grow to a statement sequence so a function reads as a
   validator. A `policy` is a wrapper of `rule` blocks — one per script purpose
   (`rule spend(...)`, `rule mint(...)`). Each rule declares its purpose inputs
   as parameters and `require`s conditions (calling helper fns, referencing
   ambient `tx.*`/`env.*`). The rules stitch into one entity — the policy hash.
   This logic/rule split is what makes pluggable backends possible.
5. **`require` is sugar over `&&`.** A `Bool` function body and a `rule` body may
   both be a sequence of `require e;` statements (conjoining), with a trailing
   result expression optional; or a single boolean expression. Both supported;
   rule bodies and fn bodies share the same statement form.
6. **datum/redeemer are rule parameters, cross-checked against templates.** Each
   `rule` declares its purpose inputs (e.g. `datum`, `redeemer`) as typed
   parameters, so it is self-describing; the analyzer checks each template's
   `datum_is` / `redeemer` against the matching rule's parameter types.
7. **Generation backend: generate-to-Aiken + delegate first**, behind a
   chain-agnostic *invariant IR* so a direct-UPLC (or ZK) backend can replace it
   without front-end changes.
8. **Spec placement.** Core operators (§4.4/§4.5/§5.5), multi-statement `fn`
   (§4.2.6/§5.6), and the `rule`-block `policy` form (§4.2.4/§7.13.4) are
   **core**; Cardano script *emission* is §8 / a codegen spec.
9. **Backend = selection (syntax) + configuration (data), kept apart.** An
   optional `via <backend-id>` clause on the policy header is the *only*
   backend-related language surface and is closed (new backends are new ids, not
   new grammar). All backend knobs are data in `trix.toml`, so adding a backend
   never introduces syntax. Omitting `via` uses the project default backend.

### Two derived rules

- **Env-in-invariants must be compile-time known.** An `env` value used inside a
  policy's logic must be resolvable from the active profile's env (it is frozen
  into the script). Using a resolution-time-only env value there is a compile
  error (analyzer diagnostic).
- **Profile-dependent identity.** A policy's hash depends on the env it was built
  against (e.g. referencing `env.treasury` hashes differently per network). The
  published TII / registry artifact must record which env produced which hash
  (ties into the existing TII-tag / codegen reproducibility discipline).

## The language addition (with examples)

### 1. Core operators: comparisons + booleans

Grammar (extends §4.4):

```
data_infix  ::= "+" | "-" | "*" | "/"
              | "==" | "!=" | "<" | "<=" | ">" | ">="
              | "&&" | "||"
data_prefix ::= "!" | "not"
```

Precedence (extends §4.5, tightest→loosest):
`.`/`[]` → `!`/`not` → `*`/`/` → `+`/`-` → comparisons → `&&` → `||`.

Operand typing (v1), reusing the §5.5.1 pairs: `==`/`!=` on `Int`, `Bytes`,
`Bool`; ordering `<`/`<=`/`>`/`>=` on `Int` (numeric) and `AnyAsset`
(**pointwise** value comparison — the "value ≥ required" floor check).

```tx3
fn in_range(now: Int, start: Int, end: Int) -> Bool {
    now >= start && now <= end
}

fn authorized(spender: Bytes, owner: Bytes) -> Bool {
    spender == owner
}

fn not_expired(now: Int, deadline: Int) -> Bool {
    not (now > deadline)
}

fn covers_floor(paid: AnyAsset, required: AnyAsset) -> Bool {
    paid >= required        // pointwise AnyAsset comparison
}
```

Because Tx3 has no `if`/ternary/control flow, a `Bool` cannot *gate* anything in
a transaction template — it can only be combined or returned from a function. So
although core, comparisons/booleans remain *practically* meaningful only as
**validator results**; scope stays contained with zero special-casing.

### 2. Multi-statement validator functions

Grammar (replaces §4.2.6 `fn_body`; the same statement form is reused by `rule`
bodies in §3):

```
fn_body      ::= stmt* data_expr?
stmt         ::= let_binding | require_stmt
require_stmt ::= "require" data_expr ";"
```

A `Bool`-returning function may omit the trailing `data_expr`; it then returns
the conjunction of its `require`s (`true` if none). Non-`Bool` functions keep
the `let* expr` form. Functions stay pure and inlined (§7.13.5); the purity rule
(§5.6.2, "no tx-local symbols") is **preserved** — a function sees only its
params.

```tx3
type VestingDatum    { beneficiary: Bytes, lock_until: Int }
type VestingRedeemer { note: Bytes }

// require-statement form
fn vesting_spend(now: Int, d: VestingDatum, r: VestingRedeemer) -> Bool {
    let grace = d.lock_until + 100000;
    require now >= d.lock_until;     // lock elapsed
    require now <= grace;            // within grace window
}

// equivalent single-expression form (decision 5)
fn vesting_spend_expr(now: Int, d: VestingDatum) -> Bool {
    now >= d.lock_until && now <= d.lock_until + 100000
}
```

### 3. Policy as a wrapper of `rule` blocks

A new `policy_def_value` form, distinguished from the existing constructor form
by the `rule` keyword (vs. `hash`/`script`/`ref`):

```
policy_def_validator ::= "{" rule_block* "}"
rule_block           ::= "rule" purpose_name parameter_list "{" stmt* data_expr? "}"
purpose_name         ::= "spend" | "mint" | "withdraw" | "publish"   // V3 purposes
// stmt / require_stmt as in §2
```

Each `rule` is named by the script **purpose** it guards and declares that
purpose's inputs as parameters (`datum` + `redeemer` for spend; `redeemer` for
mint). Its body is the §2 statement form (`let` + `require`, conjoining) — it
may call helper `fn`s and reference the ambient script context (`tx.*`, `env.*`).
A rule passes iff all its requires hold; the rules stitch into one hash. At most
one rule per purpose. On V3 each rule lowers to a branch on `scriptInfo`.

```tx3
fn lock_elapsed(now: Int, lock_until: Int) -> Bool {
    now >= lock_until
}

policy Vesting {
    rule spend(datum: VestingDatum, redeemer: VestingRedeemer) {
        require lock_elapsed(tx.validity.since, datum.lock_until);
    }
}
```

A mint rule, capped by a compile-time `env` ceiling:

```tx3
type MintRedeemer { amount: Int }

fn capped(minted: AnyAsset, ceiling: AnyAsset) -> Bool {
    minted <= ceiling
}

policy CappedToken {
    rule mint(redeemer: MintRedeemer) {
        require capped(tx.mint, env.max_supply);
    }
}
```

A policy MAY hold several rules — one script, one hash, multiple purposes — with
multi-statement bodies mixing helper calls and inline conditions:

```tx3
policy Treasury {
    rule spend(datum: TreasuryDatum, redeemer: TreasuryRedeemer) {
        let now = tx.validity.since;
        require now >= datum.unlock;
        require approved(redeemer, datum.admin);   // helper fn -> Bool
    }
    rule mint(redeemer: TreasuryRedeemer) {
        require tx.mint <= env.max_mint;           // inline condition
    }
}
```

**Script-context bindings** — within a rule body: the rule's own parameters
(datum/redeemer, author-named and typed) plus the ambient script context (a new
scope describing the tx being *validated*, distinct from a `tx` template's own
scope):

| Binding                         | Type       | Notes                              |
| ------------------------------- | ---------- | ---------------------------------- |
| rule params (`datum`,`redeemer`)| declared   | the rule's per-purpose inputs      |
| `tx.validity.since` / `.until`  | `Int`      | validity slot range                |
| `tx.fee`                        | `AnyAsset` | transaction fee                    |
| `tx.mint`                       | `AnyAsset` | net mint/burn                      |
| `env.*`                         | declared   | compile-time only (rule above)     |

Deferred (not v1): aggregate / own-input / continuing-output bindings, bounded
quantifiers over inputs/outputs, variant matching (`is`), list membership
(`contains`), multi-level/variant datum traversal. Richer logic stays the domain
of externally referenced scripts — the assign/constructor `policy` forms coexist
unchanged.

### 4. End-to-end: template references the generated policy

The template uses `from: Vesting`; the toolchain substitutes the **generated**
script address, and cross-checks `datum_is` against the `spend` rule's `datum`
parameter type (decision 6). No runtime hash reduction — the hash is a
build-time constant.

```tx3
party Claimer;

tx claim(locked_utxo: UtxoRef) {
    input locked {
        ref: locked_utxo,
        from: Vesting,                       // → generated script address
        datum_is: VestingDatum,              // cross-checked vs spend rule param
        redeemer: VestingRedeemer { note: "" },
    }
    output {
        to: Claimer,
        amount: locked - fees,
    }
    validity {
        since_slot: 1_000_000,
    }
}
```

## Chain mapping (Plutus V3)

The toolchain targets V3 (`cardano::plutus_witness { version: 3 }`). V3 unified
the script signature to `ScriptContext -> ()` (errors on fail), with
`ScriptContext = { txInfo, redeemer, scriptInfo }` and the datum carried as
`Maybe datum` inside `scriptInfo`'s `SpendingScript`. Therefore:

- One policy → one script → one hash; each `rule` lowers to a branch on the
  `scriptInfo` constructor — V3's *native* shape.
- `spend` exposes `datum` + `redeemer`; `mint` exposes only `redeemer`. `tx.*`
  maps to `txInfo` (`tx.validity` → `txInfoValidRange`, `tx.fee` → `txInfoFee`,
  `tx.mint` → `txInfoMint`).
- V1/V2 differ (arity changes per purpose), so a multi-purpose policy is
  **V3-only**; emitting V1/V2 would force one hash per purpose — a declared
  non-goal for v1.

## How scripts get generated (build time, per chain, per profile)

1. **Lower logic → a chain-agnostic *invariant IR*** — a typed predicate form
   over a script-context schema, distinct from TIR (the *transaction* wire
   format). Functions inline (§7.13.5) into one Bool expression per purpose.
   Lives alongside `core/tir`.
2. **Chain script-generation backend.** Generate into an existing validator
   language (Aiken) and delegate compilation to its binary — matches trix's
   subprocess-delegation model
   ([`../tooling/trix/design/004-toolchain-delegation.md`](../tooling/trix/design/004-toolchain-delegation.md)),
   reuses a mature/audited UPLC backend + cost optimiser, and emits the
   `plutus.json` blueprint the toolchain already understands. Swappable behind
   the invariant IR (direct UPLC / ZK later).
3. **Hash → identity.** Compile to bytes, hash (BLAKE2b-224 for the Cardano
   policy id), bake the literal hash into the lowered output. Templates resolve
   `from:`/`to:` via the **existing** `BuildScriptAddress` / `policy_into_address`
   path with no template-side changes. **Gap to fill:** the resolver has a
   `todo!()` `find_script_for_hash` and no script→hash helper — implement via
   pallas `Hasher`.
4. **trix build & publish.** New build step per profile: bind env → lower →
   generate → compile → blueprint (+ hash) → thread identity into codegen / TII
   → publish via existing `cardano::publish` (reference script) or
   `plutus_witness` (inline). Pin generator/compiler version for reproducibility.
5. **Duality test oracle.** Every declared happy-path template that touches the
   policy MUST pass the generated script; mutations (wrong owner, early slot)
   MUST fail. Wire into `trix test` / the e2e harness.

### Backend selection & configuration

Backend is a property of the **whole policy's** compilation, not of rules within
it: a policy compiles to one artifact via one backend → one hash. The enforcing
backends themselves (their compilers) are out of scope for v1, but the *syntax*
for selecting one is settled here.

**Selection (syntax) is separated from configuration (data)** — this is what
keeps the language from growing per backend:

- **Selection** — an optional `via <backend-id>` clause in the policy header,
  where `<backend-id>` is a `::`-namespaced identifier (`cardano::plutus`,
  `cardano::native`, `zk::groth16`). This is the **only** backend-related
  language surface, and it is closed: a new backend is just another id in the
  same slot, never a new grammar production. Omitting `via` uses the project
  default backend (`trix.toml`). Grammar (extends §4.2.4):

  ```
  policy_def ::= "policy" identifier ("via" backend_id)? policy_def_value
  backend_id ::= identifier "::" identifier
  ```

  ```tx3
  policy Vesting via cardano::plutus {            // explicit
      rule spend(datum: VestingDatum, redeemer: VestingRedeemer) { … }
  }
  policy Simple {                                 // project default backend
      rule spend(datum: D, redeemer: R) { … }
  }
  ```

- **Configuration** — backend knobs are **data in `trix.toml`**, never syntax,
  mirroring trix's external-tool delegation contract: each backend owns its
  config shape; trix passes it through to the backend's compiler. A new backend
  contributes a TOML schema, **not** grammar.

  ```toml
  [backend."cardano::plutus"]
  version  = 3
  optimize = true

  [backend."zk::groth16"]
  proving_key = "keys/vesting.pk"

  [policies.Vesting.backend]        # optional per-policy override
  version = 3
  ```

  An in-source escape hatch reuses the *existing* record-literal syntax
  (`via cardano::plutus { version: 3 }`) if identity-affecting config should sit
  next to the policy — still not new grammar. Default is TOML.

**Identity** becomes `hash = f(source, env, backend, resolved-config)`; the
resolved backend + config are recorded in the TII alongside env (extends the
profile-dependent-identity rule). Backends with a sensible default (plutus → V3)
need no config for the common case.

**Constraints unchanged:** keep rule/fn logic backend-neutral (no Plutus-isms in
core grammar; `tx.*` are abstract names mapped per backend). One hash is exactly
one script of one type on Cardano (no heterogeneous stitching). Capability
gating is a per-backend analyzer check (e.g. `cardano::native` rejects value
arithmetic), driven by the resolved backend — a diagnostic, not new syntax.

## Files touched (when implemented)

- **Front end** —
  [`../lang/tx3/crates/tx3-lang/src/tx3.pest`](../lang/tx3/crates/tx3-lang/src/tx3.pest)
  (comparison + boolean operators, `not` keyword, multi-statement `fn` body with
  `require`, `rule`-block `policy` form, `via` clause),
  [`src/ast.rs`](../lang/tx3/crates/tx3-lang/src/ast.rs) (operator /
  `require_stmt` nodes; new `rule`-block `PolicyValue` variant; `via` on
  `PolicyDef`), `src/parsing.rs`, `src/analyzing.rs` (Bool typing + operand-type
  rules, rule param + script-context-binding scope + resolution,
  env-compile-time-known rule, rule-param cross-check vs templates' `datum_is` /
  `redeemer`, per-backend capability gating). Operators touch §4.5 precedence.
- **IR** — new chain-agnostic invariant IR alongside `core/tir`; `lowering.rs`
  policy/fn lowering path.
- **Cardano backend** — `tx3-cardano/src/coercion.rs` (script→hash via pallas
  `Hasher`), `src/lib.rs` (`reduce_op`), `src/compile/mod.rs`
  (`find_script_for_hash`); invariant-IR → Aiken generation + blueprint.
- **trix** — build step (extract policies → generate → compile → blueprint →
  thread into codegen/TII → publish); `trix.toml` `[backend.*]` / per-policy
  config schema and default-backend resolution.
- **Spec** — new/edited sections under
  [`../lang/tx3/specs/v1beta0/`](../lang/tx3/specs/v1beta0/) per decision 8.

## Verification (when implemented)

- `policy Vesting { … }` + the `claim` template → `trix build` yields a stable
  hash; rebuild → identical hash; building against two profiles whose relevant
  env differs → two policy ids.
- Resolve `claim` (`tx3_invoke` / `trix invoke`): the input/output address for
  `Vesting` equals the generated script address; the tx validates on devnet.
- Test oracle: the happy-path `claim` passes the generated script; a mutated tx
  (wrong beneficiary / pre-lock slot) is rejected.
- Unit (`tx3_check` / `tx3_parse` over the snippets above): operators parse with
  correct precedence; `require` desugars to `&&`; a `Bool` in an `amount:`
  position is a type error; an `env` value not compile-time-known inside a policy
  is a diagnostic; a `cardano::native` policy using value arithmetic is rejected.

## Open questions (for review)

- **Multiple rules per purpose.** v1 says at most one per purpose; relax to a
  conjunction of same-purpose rules if modularity demands it.
- **Script-context surface.** v1 binds `datum`/`redeemer`/`tx.validity`/`tx.fee`/
  `tx.mint`. Own-input value and continuing-output checks are the most likely
  early additions; both need the deferred aggregate/output bindings.
- **`withdraw` / `publish` purposes.** Listed in the grammar; confirm whether v1
  ships beyond `spend` / `mint`.
