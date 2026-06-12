# Plan: Tx3 for the account model — fitness analysis & an `evm::` strawman

Status: **exploratory / strawman — not scheduled. Written for reaction, not execution.**
Scope: language design only. *If* pursued it would be cross-cutting — `lang/tx3`
core (new operators + block meta-arguments), a new `evm::` chain-extension
namespace alongside `cardano::` (spec §8), and resolver/TRP work (the plan
engine). Nothing here is committed.
Origin: design discussion (2026-06-06) evaluating whether Tx3 — a DSL built for
UTxO transaction templates — provides value on account-model chains (EVM,
Solana), and if so what language additions would be required. Terraform was
adopted as the role model for filling Tx3's control-flow gap.
Related: [`tx3-protocol-limitations.md`](./tx3-protocol-limitations.md) — the
"no dynamic input/output lists" and "no `*` / `/` operators" limitations there
are the UTxO-side shadow of the expressiveness gaps this doc proposes to close;
the language spec under
[`../lang/tx3/specs/v1beta0/`](../lang/tx3/specs/v1beta0/) (esp. §2.7 chain
genericity, §7 transaction semantics, §8 `cardano::` extensions); TII as
"OpenAPI for transactions" ([`../core/tii/README.md`](../core/tii/README.md)).

## Context

The motivating question: UTxO lacks something like the EVM ABI, and Tx3 fills
that gap for UTxO protocols. Does Tx3 carry any value to the account model,
which already *has* an ABI — even if it requires additions to the language?

The analysis hinges on one distinction. There are two different "Tx3"s:

1. **Tx3-the-transaction-body** — the §7 block vocabulary: `input` / `output` /
   `reference` / `collateral` / `mint` / `burn`, the many-input `*`, `min_utxo`,
   `datum_is`, `redeemer`, `UtxoRef`. This is what everyone *sees* in a `.tx3`
   file, and it is irreducibly UTxO-shaped.
2. **Tx3-the-architecture** — templates that declare *shape, not values*;
   `party` / `env` / `profiles`; the type system; a server-side **resolver**
   (TRP) that assembles the concrete transaction; the **TII** declarative
   interface; codegen to TS/Rust/Go/Python; the registry; frontend decoupling.

**Almost none of (1) transfers to the account model. Almost all of (2) does —
and (2) is where Tx3's value lives.** The mistake to avoid is judging
account-model fitness by the `input`/`output` blocks and concluding "this is a
UTxO language." The blocks don't transfer; the idea does.

### Does the account model even have the gap?

Yes — arguably a wider one than UTxO. The EVM ABI describes the call surface of
**one contract**. From it, `typechain` / `wagmi` / `viem` / `ethers` / `abigen`
/ `web3.py` generate typed bindings — a mature, entrenched ecosystem. But a
*protocol* is not one contract. To "swap token A for token B on a DEX" an
integrator must know, off-chain and undescribed by any ABI:

- **which contracts** (router, factory, pool, both tokens, a quoter/oracle) and
  **which addresses on which chain** (same protocol, different addresses per
  deployment);
- **the approval dance** — ERC-20 `approve` (or an EIP-2612 `permit` signature)
  must precede `transferFrom`; the #1 source of DeFi frontend boilerplate;
- **multi-call composition** — approve+swap, permit+deposit, `multicall`, or an
  ERC-4337 `UserOperation` through a bundler/paymaster, or a Safe tx;
- **parameters in no ABI** — slippage / `minOut`, deadline, routing path.

There is no widely adopted, vendor-neutral, declarative description of "to do
action X in protocol P, assemble these N calls with these parties and
parameters, adapted to this deployment." That altitude — above the contract
ABI, below the proprietary frontend — is exactly where TII sits. The OpenAPI
analogy is therefore not merely portable to the account model; it is a *better*
fit, because the account model already has the assembly-level interface and is
missing the protocol-level one.

## What transfers, and what doesn't

### Transfers cleanly (the wins)

- **`env` + `profiles` → per-deployment address management.** A slam dunk: the
  "same protocol, different addresses per chain" pain maps exactly onto
  profiles.
- **`party` → named participants.** `sender` / `spender` / `recipient` /
  `operator` map onto EOAs and signers; the abstraction is already chain-neutral.
- **The type system → ABI types, nearly 1:1.** `uint`/`address`/`bytes`/
  `bytes32`/`bool`/arrays/tuples → `Int`/`Address`/`Bytes`/`Bool`/`List`/records.
  Nominal, monomorphic, no coercions is a *good* match for ABI rigidity. (One
  real gap: `Int` must grow an arbitrary-precision / `uint256` story; the spec's
  64-bit floor, §5.1, won't do.)
- **TII → OpenAPI.** Schema-first, params as JSON Schema, profiles bind values,
  built for codegen/CLIs/UIs. The crown jewel, chain-agnostic by construction.
- **The resolver pattern → intents/solvers** (see below) — the most durable idea
  in the stack.
- **Codegen + registry + frontend decoupling** — *more* valuable on EVM, where
  thousands of deployments and a thriving aggregator ecosystem need a shared,
  discoverable protocol interface instead of per-integrator reverse-engineering.

### Does not transfer (honest mismatches)

- **The entire §7 body vocabulary is UTxO physics.** Account-model txs are
  `(from, to, value, data, nonce, gas)`; state mutates **in place** in contract
  storage. No coin selection, no value balancing (`Σinputs = Σoutputs + fee`), no
  `min_utxo`, no collateral, no datum-on-the-thing-you-spend. `input`/`output`/
  `reference`/`collateral`/`mint`/`burn`/`*`/`min_utxo` mostly evaporate.
- **The resolver does *less* intrinsic work** — thinning the value prop for the
  simple case. On UTxO it earns its keep doing coin selection + balancing + fees
  + min-utxo. On EVM, calldata *is* the transaction; for a single call a Tx3
  template is barely more than a typed `wagmi` binding (which is free and already
  there). The resolver re-earns its keep only on the *hard* cases: approval/permit
  insertion, multicall bundling, routing, gas estimation/simulation, AA/paymaster,
  nonce management. **Marginal value over incumbents is near-zero for single-call
  protocols and large only for multi-step / multi-contract / multi-deployment /
  intent flows.** Scope and sell it on the latter — protocols, not contracts.
- **`datum_is` has no analog.** UTxO carries typed state with the value you
  consume; account-model state is in storage behind getters. The closest analog
  is typing function args/returns — which the ABI already does.
- **"No control flow" collides with integration reality.** §2.3 forbids loops,
  conditionals, comparisons, and boolean combinators. Account-model integration
  is *full* of conditionality (approve-iff-short, permit-vs-approve, route A-vs-B).
  That logic must go somewhere. This is the deepest tension — and the rest of
  this doc is the proposed resolution.
- **"Account model" is not monolithic.** EVM and Solana differ a lot; Solana
  already has the Anchor IDL (an ABI/TII-like JSON description) and explicit
  account enumeration (which actually *rhymes* with UTxO input enumeration). Each
  chain family needs its own extension namespace — which the `cardano::` /
  reserved `bitcoin` design (§2.7) already anticipates. This is a point *in*
  Tx3's favor: the extension-namespace shape is the right vessel.

## The Terraform model: `trp.resolve` is already `terraform plan`

Terraform resolves the control-flow tension without imperative constructs. The
key realization: **a resolver reads observed chain state and computes a concrete
transaction from a declared template — exactly what `terraform plan` does for
infra.** So Tx3 doesn't need imperative control flow to express "approve only if
needed"; it needs the Terraform answer — declare desired state + read observed
state + let the plan engine compute the diff.

Terraform stays declarative while handling conditionality, iteration, and
ordering via five ideas, none of which is imperative control flow: **conditional
expressions** (`c ? a : b`), **`count` / `for_each`** (declarative fan-out), an
**implicit dependency DAG** (ordering from references), **`data` sources** (read
observed state), and **preconditions**. That is the bright line: Tx3 gets
Terraform-grade declarative conditionality and *nothing* that makes it
Turing-complete. The founding non-goal (§1.1 — "no constructs for unbounded
loops, recursion, or side-effects") survives intact.

### Proposed core additions (chain-agnostic)

| Addition | Terraform analog | Why needed | Why still declarative |
| --- | --- | --- | --- |
| Comparison + boolean operators (`==`, `<`, `&&`, …) → `Bool` | expression operators | §2.3 forbids these outright — too austere for "is allowance enough?" | produce *values*, not branches |
| Conditional expression `if c { a } else { b }` (yields a value) | `c ? a : b` | choose `min_out`, pick a path | an expression, no side effect |
| `when:` block meta-argument | `count = c ? 1 : 0` | a block that materializes only if a condition holds | block is in the plan or not |
| `for_each:` block meta-argument | `for_each` | N calls from a set, no loop | fully unrolled at resolve time |
| `read` blocks | `data` sources | read allowance/reserves/nonce to inform the plan | read-only, resolve-time |
| `require { … }` | `precondition` | fail with a clear error, not a malformed tx | assertions, not control flow |
| `ensure_*` desired-state effects | `resource` (create-or-no-op) | "ensure allowance ≥ X" → approve iff needed | declares end-state; resolver computes the op |

Two snags to reconcile up front:

1. **`!` operator clash.** `!` is *arithmetic* negation today (§5.5.1). Adding
   boolean `!` forces a choice — recommendation: move arithmetic negation to
   `neg(x)` and give `!` to booleans.
2. **Resolve-time only.** These operators must never leak into a position
   implying on-chain computation. The analyzer enforces the boundary, the same
   way `fn` bodies are forbidden from touching tx-local symbols (§5.6.2).

## The `evm::` namespace strawman

Same pattern as `cardano::` (§8): a chain-family namespace on an unchanged core.

- `evm::call <name> { to, function, args, value? }` — a contract call; may
  produce a named return value.
- `evm::view { to, function, args }` — a static/view call, used inside `read`.
- `evm::ensure_allowance { token, owner, spender, at_least }` — desired-state
  approval.
- `evm::permit { token, owner, spender, value, deadline }` — EIP-2612 / Permit2
  signature instead of an approve tx.
- `evm::intent { sell, buy, min_out, deadline }` — signed EIP-712 typed data,
  no on-chain call at resolve time (CoW Swap / UniswapX class).

The load-bearing move: **the template never says whether the calls become three
sequential EOA txs, one `multicall`, or one ERC-4337 `UserOperation`.** That is
the resolver's choice, driven by a profile capability — exactly as Tx3 already
hides coin selection from UTxO templates.

## Worked example — Uniswap-style "approve + swap"

```tx3
// ─── evm-uniswap.tx3  —  STRAWMAN, not valid v1beta0 ───
// "Sell an exact amount of USDC for WETH on a V2-style router."

party User;                     // EOA or smart account

env {                           // per-deployment addresses → profiles, never inline
    router: Address,
    usdc:   Address,
    weth:   Address,
}

tx swap_usdc_for_weth(
    amount_in: Int,             // USDC (6dp) to sell
    min_out:   Int,             // floor on WETH out (slippage)
    deadline:  Int,             // posix seconds
) {
    require {
        amount_in > 0,
        deadline > tip_time(),  // tip_time(): EVM cousin of tip_slot()
    }

    // DATA SOURCE — observed state at resolve time (terraform `data`)
    read allowance: Int {
        evm::view {
            to:       usdc,
            function: "allowance(address,address)",
            args:     { owner: User, spender: router },
        }
    }

    // DESIRED STATE — resolver diffs `allowance` against the need and
    // emits an `approve` ONLY if short. Pure create-or-no-op.
    evm::ensure_allowance {
        token: usdc, owner: User, spender: router, at_least: amount_in,
    }

    // THE EFFECT — the swap
    evm::call swap {
        to:       router,
        function: "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
        args: {
            amountIn:     amount_in,
            amountOutMin: min_out,
            path:         [usdc, weth],
            to:           User,
            deadline:     deadline,
        },
    }
}
```

`ensure_allowance` is sugar. Desugared, it is the primitive `when:` guard — where
the new operators earn their place:

```tx3
    // `ensure_allowance` ≡ a guarded effect:
    evm::call approve when: allowance < amount_in {
        to:       usdc,
        function: "approve(address,uint256)",
        args:     { spender: router, amount: amount_in },
    }
```

The permit-vs-approve fork — the case that *seems* to demand an `if`, expressed
with self-guarding blocks instead. No imperative branch; each block independently
decides whether it is in the plan:

```tx3
    read supports_2612: Bool {
        evm::view { to: usdc, function: "DOMAIN_SEPARATOR()", args: {} }  // presence → Bool
    }

    evm::permit when: supports_2612 {
        token: usdc, owner: User, spender: router, value: amount_in, deadline: deadline,
    }
    evm::call approve when: !supports_2612 && allowance < amount_in {
        to: usdc, function: "approve(address,uint256)",
        args: { spender: router, amount: amount_in },
    }
```

### Ordering from the data-flow graph, not line order

When one call references another's *return*, the resolver topologically sorts —
you never write "step 1, step 2":

```tx3
    evm::call open {
        to: positions, function: "mint(MintParams)", args: { /* … */ },
    }   // open.tokenId  ← return value

    evm::call stake {
        to: gauge, function: "deposit(uint256)",
        args: { tokenId: open.tokenId },   // reference ⇒ resolver orders open before stake
    }
```

Declarative iteration replaces loops outright:

```tx3
    evm::call claim for_each: id in reward_ids {
        to: gauge, function: "getReward(uint256)", args: { tokenId: id },
    }   // resolver unrolls to N calls, almost certainly one multicall
```

## Grounding against a real repo protocol (VyFi) — the intent connection

`protocols/vyfi/vyfi-dex/main.tx3` models a Cardano DEX as **two steps**: the
user posts an *order UTxO* (with an `OrderDatum`) to a per-pool script address,
and a *batcher* settles it later. On a plain EVM AMM the analog collapses to the
single `evm::call swap` above.

But on an **intent-based** EVM DEX (CoW Swap, UniswapX), the user *signs an
intent* and a *solver* settles it — structurally **the same shape as VyFi**: post
intent → off-chain actor executes. The intent-orientation that made Tx3 fit VyFi
on Cardano is the *same* property that makes it fit intent-DEXs on EVM, via
`evm::intent`. This is the most differentiated position for Tx3 on the account
model, because it sits *above* the ABI entirely — riding ERC-4337 / ERC-7683 /
UniswapX / CoW rather than competing with `wagmi` at the contract-binding
altitude (where it would lose).

## Terraform mapping

| Terraform | Tx3 (proposed) | Status |
| --- | --- | --- |
| `resource` (desired state, idempotent) | `evm::ensure_*` blocks | new |
| effect with side-effect-once | `evm::call` / `evm::intent` | new |
| `data` source | `read { … }` | new (generalizes `reference`) |
| implicit dependency DAG | reference graph → resolver topo-sort | new analyzer pass |
| `count` / `for_each` | `for_each:` meta-arg | new |
| `count = c ? 1 : 0` | `when:` block guard | new |
| ternary `c ? a : b` | `if c { a } else { b }` expression | new |
| `precondition` / `postcondition` | `require { … }` | new |
| provider | chain namespace (`evm::`, `solana::`) | pattern exists (`cardano::`) |
| **`terraform plan`** | **`trp.resolve`** | **exists** |
| **`terraform apply`** | **`trp.submit`** | **exists** |
| `.tfstate` (owned, persistent) | — *(no analog)* | see caveats |

The bottom rows are why this is tractable rather than a rewrite: the *engine*
already exists. The work is teaching the language to express what the engine can
already do.

## Where the Terraform analogy honestly breaks

1. **No persistent state file — and that's mostly good.** Terraform owns
   long-lived mutable infra and reconciles desired-vs-actual *repeatedly*. A
   transaction is a **one-shot** state transition; the "actual state" is the
   chain, owned by no one, re-read fresh each `resolve`. The reconcile loop is
   degenerate (plan-once, apply-once). This simplifies things but means
   Terraform's idempotency only partly holds.
2. **Idempotency splits the vocabulary in two.** `ensure_allowance` is idempotent
   ("make allowance ≥ X" → re-running is safe) — pure Terraform. But
   `evm::call swap` is **not** — resolve+submit twice and you swap twice. So the
   language must visibly distinguish **desired-state** blocks (`ensure_*`,
   idempotent) from **effect** blocks (`call` / `intent`, perform-once).
   Terraform never makes this distinction because *everything* is desired-state.
   A genuine conceptual addition, not a borrow.
3. **Atomicity is a footgun the resolver must own.** A multi-call plan
   (`approve` → `swap`, or `open` → `stake`) is atomic **only** if lowered to a
   `multicall` or a 4337 `UserOperation`. Lowered to sequential EOA txs, `approve`
   can land while `swap` reverts — a partial apply with no rollback. Worse, the
   `open.tokenId → stake` dependency *requires* an atomic batch (the return must
   feed the next call in the same tx) and is unrepresentable as sequential txs. The
   resolver must (a) detect intra-tx data dependencies and force a batch, and
   (b) surface the atomicity guarantee of the chosen lowering. **This is the one
   place the UTxO model is strictly cleaner** — a Cardano tx is atomic by
   construction. On EVM, atomicity becomes a first-class resolver concern and
   arguably a `require atomic;` template assertion.

## Non-goals — what we deliberately do not add

No `for`/`while`, no mutable variables, no unbounded recursion, no general
statements, no early return. The expression language stays pure and bounded.
Everything proposed is either a *value* (conditional expr, comparisons), a
*declarative quantifier over structure* (`when` / `for_each`), a *read*, or an
*assertion* — the exact set Terraform gets away with while remaining declarative.

## Net assessment

- **Language as-is: poor fit.** The visible §7 surface is UTxO physics; ~80% of
  the block vocabulary does not carry over. Do not market `input`/`output` blocks
  to EVM developers.
- **Architecture & value prop: strong fit, possibly stronger than on UTxO.** The
  protocol-interface-description + codegen + frontend-decoupling layer addresses
  a real, currently-unmet gap on account-model chains — the chasm between the
  contract ABI and what an integrator must assemble. The chain-genericity design
  is the right shape to absorb a new chain family.
- **The catch:** marginal value over mature incumbents is thin for single-call
  protocols, large for multi-step / multi-contract / multi-deployment / intent
  flows. Scope to the latter.
- **The decision that determines success:** how to handle conditional integration
  logic without abandoning "the declarative interface is the full spec." The
  Terraform model above is the proposed answer — declared desired-state +
  reads + guards + dependency DAG, resolved by the plan engine — not imperative
  control flow.

## Open questions / next steps (if pursued)

- A one-page `evm::` mini-spec in the shape of §8 (grammar fragments + field
  tables for `evm::call` / `view` / `ensure_allowance` / `permit` / `intent`,
  plus the `when:` / `for_each:` / `read` / `require` core additions). That is the
  artifact to circulate for reaction.
- Decide the `!` operator reconciliation (arithmetic `neg()` vs boolean `!`).
- Decide `Int` → arbitrary-precision / `uint256`.
- Prototype the dependency-DAG + atomicity-forcing pass in a resolver spike
  against a single real protocol (a Uniswap V2 approve+swap) before any language
  change lands.
- Evaluate whether `read` / `when:` / `for_each:` / `require` and the new
  operators should land in the **core** (they would also relieve documented UTxO
  limitations — dynamic lists, comparisons; see
  [`tx3-protocol-limitations.md`](./tx3-protocol-limitations.md)) or stay gated
  behind chain extensions.
