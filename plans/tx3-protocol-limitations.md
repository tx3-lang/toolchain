# tx3 limitations encountered while modelling protocols

## Context

This document collects the tx3 language and toolchain limitations surfaced while implementing the seven protocols under `protocols/`. Each section pulls from the per-project limitations file that previously lived next to the protocol's README (or, for protocols without a standalone file, from the README itself). The four standalone `tx3-limitations-*.md` files inside protocol directories are still in place — this consolidated doc is a digest, not a move.

Cross-cutting themes that show up in more than one protocol:

- **No `*` / `/` operators** — every protocol that does arithmetic (Bodega fee math, Snek bonding-curve aggregates, Indigo collateral ratios) forces the caller to pre-compute totals.
- **Reference-input datums are partially readable** — `datum_is` (tx3#318) made simple field access work, but only in datum construction; field access in amount expressions still fails, and accessor multi-level paths still don't work.
- **Custom types (enums, on-chain `Address`) can't be passed as invoke params** — forces tx duplication (Bodega `_yes`/`_no`) or raw-CBOR shims (Fluid `batcher_addr_cbor`, `staker_redeemer_cbor`).
- **Staking key not extractable from a party** — `signers` only pulls the payment key, so protocols that need the stake-key as required signer (Fluid `execute_scheduled`, Fluid `stake_fldt`) pass it as a raw `Bytes` param.
- **No dynamic input/output lists** — blocks every batcher / multi-position transaction (Bodega's 5 batcher txs, Snek pool spends, VyFi batcher side, Hydra's per-participant outputs).

---

## Indigo

Discovered with trix 0.21.1 (2026-04-07). Updated 2026-04-15 after tx3c fixes [#316](https://github.com/tx3-lang/tx3/pull/316), [#318](https://github.com/tx3-lang/tx3/pull/318).

### Bugs (resolved)

#### Type names starting with primitive keywords (parser)

Custom type names starting with `Int`, `Bool`, `Bytes`, `Address`, `UtxoRef`, or `AnyAsset` cause parse failures. PEG parser matches the primitive keyword greedily.

- **Example:** `InterestData` → parser matches `Int`, fails on `erestData`.
- **Workaround applied:** Renamed to `CdpInterest`. (Still in place — bug not yet fixed.)
- **Fix for tx3-lang:** `("Int" | ...) ~ !ASCII_ALPHANUMERIC`

#### Param/field name collision (lowering panic) — FIXED ([#316](https://github.com/tx3-lang/tx3/pull/316))

When a tx param had the same name as a type field, lowering panicked with `not yet implemented`. Example: param `owner_pkh` collided with `CDPCreatorRedeemer::CreateCDP { owner_pkh }`. Fixed in tx3c [#316](https://github.com/tx3-lang/tx3/pull/316); prefixes (`cr_owner`, `ci_timestamp`) removed.

### Active limitations

#### No multiplication / division

Only `+` and `-` supported. Cannot compute collateral ratios, interest rates, or prices.

- **Impact:** All computed values must be pre-calculated by the API caller before invoking.
- **Affected params:** Collateral ratios, protocol fees, price calculations.

#### Cannot read datum from reference inputs — SYNTAX FIXED ([#318](https://github.com/tx3-lang/tx3/pull/318))

`reference` blocks now support `datum_is` to parse and expose datum fields. Field access works for `oracle_data.od_price`-style access on all 4 CDP oracle references.

However, `timestamp_ms` and `interest_accumulator`/`accumulator` remain as caller-provided params. On-chain analysis confirmed these values do NOT come from the oracle datum:
- `timestamp_ms` is the user's "current time" (differs from `od_expiration` by days)
- `interest_accumulator`/`accumulator` differs from `od_nonce`

The oracle reference input is used by the on-chain validator for price/interest rate checks, but the timestamp and accumulator are provided independently by the caller.

**Still blocked (spent inputs + variant types):** SP pool/account UTxOs are SPENT inputs (not reference inputs), and `StabilityDatum` is a variant type. These params remain:

| Param | Blocked by |
|---|---|
| `sp_snapshot_p/d/s/epoch/scale` | spent input + variant field access |
| `pool_iasset` | same |
| `owner_pkh` (SP txs) | same |
| `iasset_name` (SP txs) | same |
| `acc_snapshot_p/d/s/epoch/scale` | same |

#### Datum field access on variant types

Field access (`input.field`) works on record types but fails on variant types with "not in scope". Spread (`...input`) inside a variant constructor does work.

- **Impact:** SP pool and account datums (`StabilityDatum::PoolState`, `StabilityDatum::Account`) require all fields as explicit params instead of reading from the input datum. Primary remaining blocker for reducing SP tx params (~13 across 3 SP txs + `close_cdp`).
- **Works:** `...position_input` inside `StakingDatum::StakingPosition { ... }`
- **Fails:** `account_input.acc_content.acc_owner` on `StabilityDatum` (variant)

Not addressed by [#316](https://github.com/tx3-lang/tx3/pull/316) or [#318](https://github.com/tx3-lang/tx3/pull/318).

### Future limitations (not blocking today)

#### No tuple types

Cannot represent `Map<Int, (Int, POSIXTime)>`.

- **Impact today:** None — on-chain staking uses empty datums `Constr(0, [])`.
- **Impact on VX staking upgrade:** Will block modeling `StakingPositionContent.lockedAmount` when Indigo activates VX staking validators with full datum fields.
- **Proposed fix:** Add tuple support or allow named records as Map values.

---

## Strike Staking

Discovered with trix 0.20.0 (2026-03-30).

### Bugs (resolved)

#### Param/field name collision — FIXED ([#316](https://github.com/tx3-lang/tx3/pull/316))

Param/env var names colliding with type field names used to panic `trix build`. Params and env vars now use their original names (`amount`, `staked_at`, `mint_policy_id`) directly.

#### Datum spread on consumed inputs — FIXED

The spread syntax (`...current_stake`) to propagate datum fields from a consumed input used to fail at runtime with `property index 0 not found in None`. Now works; `add_stake` uses `datum: StakingDatum { ...current_stake }` directly and the `staked_at` param was dropped from that tx.

### Active limitations

#### `slot_to_time()` returns seconds, not milliseconds

The `staked_at` datum field requires POSIX time in ms (Plutus convention). `slot_to_time()` returns seconds, so the caller must compute the ms value externally. Without `*`, even with the seconds value we can't do `slot_to_time(tip_slot()) * 1000`.

A `slot_to_time_ms()` builtin (or `slot_to_time()` returning ms) would eliminate the `staked_at_time` param from `stake`.

#### `collateral_return` / `total_collateral` not generated

Real on-chain txs include explicit `collateral_return` (field 16) and `total_collateral` (field 17). The TRP does not generate these. Functional (txs still validate) but the CBOR diverges from what wallets produce. Cosmetic.

---

## Bodega Market

Discovered with trix 0.21.1 (2026-03-13). Updated 2026-04-14 with tx3c v0.17.0 / trix 0.22.0 findings.

### Active limitations

#### No multiplication or division operators

The grammar supports only `+` and `-`. Bodega requires arithmetic for fee and payment math:

```
payment   = buy_amount * unit_price
admin_fee = buy_amount * admin_fee_percent * 1_000_000 / 10_000
total     = payment + admin_fee + batcher_fee + envelope_amount
```

Forces `total_lovelace` and `unit_price` to be pre-computed by the API caller, leaking the fee formula and AMM pricing into the caller layer. Affects `buy_position_yes/no` and `sell_position_yes/no`.

#### No dynamic-length input/output lists (batch patterns)

tx3 requires each input/output to be declared statically. No way to express "for each position in the batch, include an input and an output". **Makes all batcher/admin operations impossible to model.** The Aiken redeemer carries `pos_indices: List<(Int, Int)>` — a dynamic list of (input_idx, output_idx) pairs.

| Tx not implementable | Aiken redeemer | Why |
|---|---|---|
| Process Buy (batch) | `PredictionRedeemer::Apply` | Dynamic list of position inputs/outputs |
| Process Reward (batch) | `PredictionRedeemer::Reward` | Dynamic list + burn + oracle reference |
| Process Refund (batch) | `PredictionRedeemer::Refund` | Dynamic list + burn |
| Withdraw Admin Fees | `PredictionRedeemer::WithdrawFee` | Multi-validator tx |
| Close Market | `PredictionRedeemer::Close` | Multi-validator consume + NFT transfer |

5 of 11 transactions blocked.

#### No tuple types

`List<(ByteArray, Int)>` can't be represented. The on-chain V2 source uses `predictions: List<(ByteArray, Int)>`. The deployed contract avoids this by using individual fields (`yes_shares`, `no_shares`, `yes_price`, `no_price`) — modelled here as a flat record. No data loss, but would block modeling the V2 GitHub source faithfully.

#### Custom types (enums) cannot be passed as parameters

`from_json()` in `tx3-resolver/src/interop.rs` only supports Int, Bool, Bytes, Address, UtxoRef. The `CandidateIdx` enum (`Candidate0` / `Candidate1`) cannot be passed dynamically — every tx that takes a candidate index is duplicated into `_yes` / `_no` variants. 3 → 6 txs.

#### No conditional logic / branching

Bodega supports markets where payment is either ADA or a custom token. Value structure differs:
- **ADA market:** lovelace includes payment + fee + envelope + batcher_fee
- **Token market:** lovelace = envelope + batcher_fee, token amount = payment + fee

No `if/else` or `when` to branch on `payment_policy_id`. Workaround would be `_ada`/`_token` variant duplication. Not implemented today (all active mainnet markets use ADA).

#### Reference datum fields only usable in datum construction

Discovered with tx3c v0.17.0 / trix 0.22.0 (2026-04-14).

`datum_is` lets you read reference datum fields, but the resolver only handles them inside **output datum construction** — not in **amount expressions** (`Ada(...)`, `AnyAsset(...)`, `min_amount`, change calculations).

```tx3
reference project_info { ref: project_info_ref, datum_is: ProjectInfoDatum }

// WORKS — datum field in output datum
output { datum: PositionDatum { outref_id: project_info.outref_id } }

// FAILS — datum field in amount expression
output { amount: Ada(project_info.pi_envelope_amount + batcher_fee_amount) }

// FAILS — datum field in AnyAsset
locals { shares: AnyAsset(project_info.pi_share_policy_id, project_info.candidate_yes_name, amount) }
```

Error: `expected assets, got EvalBuiltIn(Add(Assets([...]), EvalBuiltIn(Property(...))))`.

Fields that could otherwise eliminate caller params (`pi_envelope_amount`, `pi_share_policy_id`, `candidate_yes/no_name`) must stay as caller-provided params because they're used in amount calculations. Only `outref_id` (datum-only usage) is read from the reference.

**Potential fix:** the resolver needs to evaluate reference datum field access at resolve time (fetch UTxO, decode datum, extract value) before building amount expressions.

### Non-issues / clarifications

- **`admin_fee_percent` must remain a caller parameter** — on-chain analysis (market 1B60_CRUDE_OIL_CLOSES) shows `pos_admin_fee_percent` in PositionDatum can differ from `ProjectInfoDatum.admin_fee_percent` within the same market (values 200 and 10 observed). The deployed contract uses per-position fee values, likely a BODEGA holder discount mechanism.
- **`collateral_return` / `total_collateral` not generated** — same cosmetic divergence as Strike Staking.

---

## Fluid Aquarium

Discovered with trix 0.21.1 (2026-04-08). Updated 2026-04-14 with unreleased fixes.

### Resolved

#### Param/field name collision — RESOLVED ([tx3#316](https://github.com/tx3-lang/tx3/pull/316))

Same as Indigo. All type-field prefixes (`ct_`, `td_`, `co_`, `st_`, `opf_`) removed.

#### Withdrawal redeemer not generated in witness set — RESOLVED ([tx3#317](https://github.com/tx3-lang/tx3/pull/317))

**Was: severity high — blocked on-chain execution of `consume_oracle`.** The `cardano::withdrawal` block correctly added the withdrawal entry to the tx body but the corresponding redeemer (purpose=reward, index=0) was not generated in the witness set. Fixed: `consume_oracle` now generates both the spend redeemer (`ConsumeOracle`, tag=4) and the reward redeemer (`OracleRedeemer::FeedCharlie`) in the witness set. No external CBOR post-processing needed.

### Partially resolved

#### Reference datum access — PARTIALLY RESOLVED ([tx3#318](https://github.com/tx3-lang/tx3/pull/318))

`datum_is` lets reference blocks expose typed datum fields. **What works:** 1-level field access compiles and resolves (`ref.field` where field is a top-level datum field). **What doesn't:**

1. **Multi-level field access:** `ref.field.subfield` fails at compile time with "not in scope: subfield". Only 1 level of `.field` is supported.
2. **Field accessor resolves to Assets, not datum:** at runtime `ref.field` resolves the reference to its UTxO value (Assets type), not to the datum. The Assets type doesn't support property access — even index 0 fails. Tested with both `params_data.min_to_stake` (idx 0) and `params_data.min_ada` (idx 3): both fail with `property index N not found in Assets([...])`. The `datum_is` annotation does not change what the reference resolves to.

Tested with Charli3 oracle provider datum (`b7ba3c4a...#1`): runtime reads the full datum structure (`Struct(constructor: 0, fields: [Struct(constructor: 2, fields: [Map([(0, 270171), (1, 1776135202109), (2, 1776221602109)])])])`) but cannot extract values.

**Impact on Aquarium:**
- `oracle_price`, `oracle_valid_from`, `oracle_valid_to` (oracle provider datum) → remain as invoke params
- `params_data.min_ada` (ParamsDatum) → `payment_ada` remains as invoke param
- Oracle feed UTxO (`7f3bb225...#0`) has no datum — just an NFT marker

What was achieved without `datum_is`: `consume_oracle` reduced from 21 → 17 params by moving `oracle_feed_ref`/`oracle_contract_ref` to env and reusing `payment_token_policy`/`payment_token_name` for the oracle token fields. A working `datum_is` would eliminate 4 more (`oracle_price`, `oracle_valid_from`, `oracle_valid_to`, `payment_ada`).

**Proposed enhancements:**
1. Fix field accessor to read from datum (not UTxO assets) when `datum_is` is specified.
2. Support multi-level field access: `ref.field.subfield`.

### Active limitations

#### Custom types cannot be passed as parameters

The `Bytes` type wraps values as CBOR ByteString, not raw Plutus Data. `execute_scheduled`'s `batcher` field in the `ScheduledTx` redeemer expects an on-chain `Address` type (Constr with payment/stake credentials). Passing it as `Bytes` produces a ByteString wrapper instead.

**Workaround:** pass `"00"` placeholder for `batcher_addr_cbor`. For production, the caller must construct the full redeemer CBOR externally.

#### List values cannot be passed as invoke parameters

`List<T>` works in type definitions and as hardcoded literals (`[]`), but cannot be passed as JSON invoke args (`from_json()` only supports Int, Bool, Bytes, Address, UtxoRef). The `signatures` field of `OracleRedeemer` is `List<OracleSignature>`. PriceDataCharlie txs on-chain use 0 signatures, so `[]` is hardcoded in source. If a variant required non-empty signatures, they could not be passed dynamically.

#### Signers extracts payment key — some validators need staking key

`signers { Party, }` extracts the payment key hash. Correct for `consume_oracle` and `withdraw_tank`. But `execute_scheduled` and `stake_fldt` need the **staking key hash** as required signer (the Aiken validators extract it from `address.stake_credential`). tx3 has no way to extract the staking key from an address.

**Workaround:** pass `signer_hash: Bytes` (the staking key hash) explicitly.

**Proposed enhancement:** `signers { stake_key_of(Party), }` or similar.

#### Collateral requires pure ADA UTxO

`collateral {}` resolves a UTxO from the specified party's address. Cardano requires collateral to be pure ADA. If the wallet's UTxOs all carry native tokens, resolution fails with "Input not resolved". Use wallets with at least one pure-ADA UTxO.

### Non-issues

- **Metadata:** on-chain Aquarium txs contain `CBORTag(259, {})` as auxiliary data — an empty CIP-68 metadata tag. Not protocol-specific, not modeled.
- **Redeemer index differences:** generated redeemer indices may differ from on-chain because input ordering depends on UTxO selection at build time. Expected.

---

## Snek.fun

Lifted from the snek-fun README's "tx3 limitations" section (no standalone file).

#### No `*` / `/` operators

Every aggregate amount (escrow totals, pool seed split, etc.) must be pre-summed by the caller. The launch tx alone takes 6 separate pre-summed figures (`total_escrow_ada`, `pool_seed_ada`, `creator_min_ada`, etc.).

#### No deeply-nested enum variants

The owner address inside `OrderDatum` is modelled as a chain of single-field structs (`CardanoAddress → OrderPayment + OrderStakeJust → OrderStakeCred → OrderPayment`) instead of the natural `Address(Credential, Maybe StakingCredential)` shape. Constructing nested variants currently trips the tx3 resolver with `invalid hex: Invalid character 'r' at position 3`.

#### Per-launch parameterised script

`token_script` is passed in as raw CBOR via `cardano::plutus_witness` because the policy is parameterised per launch (new policy id every time). tx3 cannot apply parameters to a script template.

#### Pool spend not modellable

Filling an order against the bonding curve requires the permitted-executor signature plus dynamic input/output ordering against the pool UTxO. This cannot be expressed in tx3 today and is left to the snek.fun batcher.

#### Direction marker fixed at 1

`OrderAmount.direction` is hardcoded to `1` (exact-input variant). The `direction=0` "buy-with-output" mode is not implemented.

---

## VyFi DEX

No significant tx3 limitations encountered. Order submissions are plain payments with inline datums — no script execution, no complex redeemers. The two-step model means all validator logic runs on the batcher side (not implemented in this tx3).

---

## Hydra Heads

Lifted from the "Modelling notes / known simplifications" section of `protocols/acme/hydra-heads/README.md`. These are places where the tx3 model deviates from the real Hydra on-chain protocol, called out so future work can refine them.

#### PT bundles instead of per-participant outputs

Real Hydra emits one `µInitial` UTxO per participant (each holding its own PT). The tx3 model uses an aggregate via `pt_count`. Resolved by a future "dynamic output list" feature (same shape as Bodega's blocker).

#### One `µCommit` input per tx

`collectCom` / `abort` are written for a single committed UTxO. For N participants, replicate the `commit_in` block N times. Same root cause as PT bundles — no dynamic input list.

#### Single fanout recipient

`fanout` produces one consolidated output to `fanout_recipient`. Real fanout produces one output per UTxO in the final snapshot. Same root cause.

#### `empty_contesters`

tx3 has no empty-list literal in this position, so `close` takes `initial_contesters: List<Bytes>` as a parameter — pass an empty list at call time. Same family as Fluid's "List values cannot be passed as invoke parameters" — works only because the literal is in source, not in invoke args.

#### Validity ↔ datum-deadline

`recover` and `fanout` need `validity.since_slot ≥ deadline`, but tx3 can't yet read the datum into the validity block, so the caller passes the slot. Related to the wider "reference datum access in expressions" limitation.

---

## Cross-cutting follow-ups

A short triage list of tx3 toolchain changes that would clear multiple protocols at once:

| Change | Unblocks |
|---|---|
| `*` / `/` operators | Indigo (collateral ratios), Bodega (`total_lovelace`, `unit_price`), Snek (~6 aggregates), Strike (`slot_to_time` ms conversion) |
| Reference-datum field access in amount expressions | Bodega (4 params), Indigo (oracle-derived params), Fluid (4 oracle params + `payment_ada`) |
| Multi-level reference-datum field access | Fluid (Charli3 nested datum), Indigo (variant-type datum access) |
| Dynamic input/output lists | Bodega (5 batcher txs), Snek (pool fills), Hydra (per-participant outputs, multi-commit collectCom, multi-output fanout) |
| Custom types (enums, on-chain Address) as invoke params | Bodega (collapse `_yes`/`_no` and prospective `_ada`/`_token`), Fluid (`batcher_addr_cbor`, `staker_redeemer_cbor`) |
| Stake-key extraction in `signers` | Fluid (`execute_scheduled`, `stake_fldt`) |
| List values as invoke params | Fluid (oracle signatures), Hydra (`initial_contesters`) |
| `slot_to_time_ms()` builtin | Strike (`staked_at_time`) |
| `collateral_return` / `total_collateral` in TRP output | Strike, Bodega (cosmetic CBOR parity with wallets) |
| Variant-type datum field access on spent inputs | Indigo (~13 SP params) |
| Tuple types | Indigo (VX staking upgrade), Bodega (faithful V2 source modelling) |
