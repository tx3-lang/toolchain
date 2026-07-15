# Plan: pallas script context must receive POSIX times in ms, not s

Status: **open / not started — highest user impact (burned collateral, silent timeouts)**
Scope: `backends/` — the pallas/dolos script-context bridge feeding
Plutus `POSIXTime` to validators. Possibly `core/` TIR time semantics.
Origin: user feedback doc (Asteria, Strike Staking, general).

## Context

Multiple protocols' validators fail with `TxScriptFailureError` under
tx3-built CBOR, while the SAME CBOR submits successfully via Eternl.
Repro: break the script's temporal checks. Confirmed diagnosis in the
doc: "pallas' script context is receiving posix times in seconds.
Multiplying by 1000 solves the issue."

Symptoms:

- Collateral burned on failed txs (e.g. 9927 ADA in preview tx
  `9947ae8a...`); multiple asteria preview txs cited
  (`baa12dea...`, `39a1cdf3...`, `e74c6897...`, `f8600069...`).
- Asteria `create_ship` with `tip_slot: slot+400` +
  `last_move_timestamp: Date.now()+300000` → script failure.
- Strike Staking: `TxScriptFailureError` opening a staking position;
  with staking time zero, tx fails by timeout; can't submit via Eternl.
- "Runtime error when calling `time_to_slot` with posix time passed as
  tx arg."
- Errors hidden by tx3: invalid validity-interval slot (out of era)
  surfaces only as a tx-submission timeout; Eternl shows the real cause.

Related (cosmetic, same area): `collateral_return` / `total_collateral`
not generated (tx body fields 16/17) — diverges from wallet-produced
CBOR. Already noted in `plans/tx3-protocol-limitations.md` (Strike,
Bodega).

## Approach

1. Locate where POSIXTime is injected into the pallas script context
   (likely `backends/dolos` or the TRP submit path). Confirm it passes
   seconds; Plutus expects milliseconds.
2. Multiply by 1000 at the injection point (or change the unit to ms
   end-to-end). Add a unit test asserting the injected value is ms.
3. Audit `slot_to_time()` / `time_to_slot()` builtins (see Strike
   `slot_to_time()` returns seconds, not ms —
   `plans/tx3-protocol-limitations.md`). Either return ms or add
   `slot_to_time_ms()`. Coordinate with `lang/` if the builtin lives
   there.
4. Surface detailed validity-interval / script-failure errors to the
   caller instead of masking as "tx submission timeout" (compare
   Eternl's detail).
5. (Separate, lower priority) Generate `collateral_return` +
   `total_collateral` in the TRP output for CBOR parity.

## References

- `plans/tx3-protocol-limitations.md` — Strike "`slot_to_time()`
  returns seconds, not milliseconds"; "`collateral_return`/
  `total_collateral` not generated".
- Preview txs: `9947ae8a...`, `baa12dea...`, `39a1cdf3...`,
  `e74c6897...`, `f8600069...`.
- `backends/AGENTS.md` for the pallas/dolos routing.

## Verification

- Reproduce asteria `move_ship` / `gather_fuel` / `mine_asteria` CBORs
  from the doc; confirm they submit successfully (no script failure, no
  collateral burn) on preview.
- Strike `open staking position` succeeds without manual time hacks.
- `time_to_slot` / `slot_to_time` round-trips in ms.

## Depends on / unblocks

- No upstream dep. Unblocks Strike Staking runtime; stops collateral
  burn across all time-checking validators. Do early (highest impact).
