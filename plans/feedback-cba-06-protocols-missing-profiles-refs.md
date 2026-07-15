# Plan: fill missing .tii profiles + ref UTxOs across protocols

Status: **open / not started — broadest reach**
Scope: `protocols/` fixtures (asteria, bodega, fluid, indigo,
partner-chain-gov, hydra-heads, strike, sundae-v3). Plus Indigo CDP
ref-input count and Hydra-heads env/index mismatches.
Origin: user feedback doc (profiles matrix, Indigo, Hydra, Partner
Chains).

## Context

The doc's profiles matrix shows Local/Preview/Preprod almost entirely
❌; only Mainnet ✅ for several protocols, and sundae-v3 the only one
with Local+Preview. Specific gaps:

- Partner-chain-gov: empty `environment`/`parties` for all 4 channels
  (`open-tx3/acme-protocols@db57ce7`).
- Indigo: profile only for mainnet; CDP create requires 7 reference
  inputs but mainnet ones only have 5 (mainnet tx `696c773e...`).
- Hydra-heads: missing indexes in `.tii` profiles' ref UTxOs; env file
  covers 4 indexes but deploy tx has 2 outputs (1 with ref script).
- Asteria/bodega/fluid/strike: missing Local/Preview/Preprod profiles.

## Approach

1. For each protocol, populate the missing channel profiles in the
   `.tii` (deploy the scripts where needed on preview/preprod, record
   the ref UTxOs).
2. Indigo: add the 2 missing reference inputs to the CDP-create profile
   (audit the mainnet tx for the full ref set).
3. Hydra-heads: reconcile env-file indexes (4) with the deploy tx (2
   outputs, 1 ref script) — either trim the env to match the deploy, or
   redeploy to produce the missing ref UTxOs. Add the missing indexes
   to the `.tii` profiles' ref UTxO list.
4. sundae-v3: fill the missing Preprod profile (only Local/Preview/
   Mainnet present).
5. Coordinate with cluster 3 (codegen casing) — regenerate clients
   after profiles land and re-run the protocol verify skill
   (`protocols/skills/verify-protocols/`).

## References

- `protocols/AGENTS.md`; `protocols/skills/verify-protocols/`.
- `plans/tx3-protocol-limitations.md` (per-protocol notes).
- `open-tx3/acme-protocols@db57ce7` (partner-chain-gov empty env).

## Verification

- `protocols/skills/verify-protocols/` passes for every protocol across
  all declared channels.
- Indigo CDP create resolves with 7 reference inputs.
- Hydra `init` resolves with correct ref UTxO indexes.
- Profiles matrix is green for all declared channels.

## Depends on / unblocks

- Depends on clusters 1 (lang), 2 (backends), 3 (codegen) for clean
  end-to-end runs. Do after those land.
