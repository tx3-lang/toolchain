# Plan: DX e2e harness — journey roadmap

Status: **open / not started** — the harness ships with `01-basic-init` and
`02-lang-tour`; these are the candidate journeys to grow coverage.
Scope: the `e2e/` harness (new `journeys/<NN>-<name>/`), plus the surfaces each
journey exercises — `trix codegen` + an SDK (`sdks/`), the registry
(`services/registry`), live TRP endpoints, and the `protocols/` fixtures.
Origin: extracted from `e2e/README.md` so the runnable harness stays a lean
reference and the roadmap lives with the other plans.
Related: [`dx-e2e-findings-followups.md`](./dx-e2e-findings-followups.md) (the
fixes for what the first journeys surfaced), [`e2e/README.md`](../e2e/README.md),
and the `add-e2e-journey` skill (`skills/add-e2e-journey/SKILL.md`) — the
canonical guide for actually authoring a journey.

## Context

Each journey is a self-contained script that drives the real `trix` binary
through one developer scenario and asserts the outcome; `e2e/run.sh` discovers
`journeys/*/journey.sh` automatically. Today's two cover the *runtime* round-trip
on the default scaffold (`01`) and the *compile/lower* breadth of the language
surface (`02`). The journeys below extend coverage outward along the developer
journey — codegen, registry, live networks, real protocols. They are ordered by
how self-contained they are: `03` needs only a Node toolchain; `06` needs the
`trix test` fix first; `04`/`05` need external infra or secrets and belong in a
separate CI job from the fast, offline `01` gate.

Author each one with the `add-e2e-journey` skill — it owns the journey contract,
the `lib/common.sh` helper API, fixtures, and `xfail` conventions. This plan only
defines *what* each journey should exercise.

## Workstreams

### 3. `03-codegen-consume` — generated client compiles (and invokes)

Exercise the `trix codegen` → generated SDK path that nothing in the harness
touches yet. Scaffold, `trix codegen --plugin ts-client`, then compile the
generated TypeScript client to prove the codegen output is well-formed against the
project's TII.

- **Phase A (offline, no devnet):** generate + typecheck/compile the client. The
  ts-client templates come from `tx3-lang/web-sdk` (`.trix/client-lib`); assert the
  output dir is populated and `tsc`/build succeeds. This is the cheap, high-value core.
- **Phase B (round-trip):** import the generated client in a tiny host script and
  invoke a tx against the local devnet (or `--skip-submit` to validate unsigned-CBOR
  build). Pairs with the `01` devnet machinery.
- **Deps/CI:** adds a Node toolchain (`actions/setup-node`) — still no secrets, so it
  can ride the default matrix once Node is provisioned. Consider a second job to keep
  the no-Node `01`/`02` gate minimal.

### 4. `04-registry` — publish → use → invoke an interface

Exercise the protocol-reuse path: `trix publish` a protocol to a registry, then in a
separate consumer project `trix use <scope>/<name>:<ver>` and invoke the interface tx.

- **Needs infra:** an OCI registry (`oci.tx3.land`, or a throwaway local registry the
  journey stands up) plus publish auth (OIDC / GitHub App attestation — see
  `tooling/trix/src/commands/publish.rs` and `interfaces/`). The publish + trust-pin
  flow is the hard part; a local registry fixture keeps it hermetic.
- **Scope:** registry-dependent; gate it in a job with whatever registry/auth it needs.
  A reduced first cut can publish to a local registry and `use` it without live OIDC.

### 5. `05-live-network` — preview/preprod invoke (secrets-gated)

Invoke a real transfer against a live Cardano testnet (preview/preprod) via a Demeter
TRP endpoint — the only journey that leaves the local devnet.

- **Reuse:** mirror the existing SDK e2e harness `sdks/scripts/run-e2e-tests.sh` and its
  env contract (`TRP_ENDPOINT_PREPROD`, `TRP_API_KEY_PREPROD`, funded test wallets
  `TEST_PARTY_A/B_*`). Use the same GitHub secrets.
- **Scope:** **secrets-gated, separate CI job** — never on the fast offline gate. Likely
  `--profile preview`/`preprod` with funded identities; assert on the submitted tx /
  resolver response rather than balances (testnet timing).

### 6. `06-protocol-fixture` — a real protocol through `trix test`

Run a real protocol from `protocols/<name>/` (each ships `trix.toml` + `main.tx3` +
`tests/basic.toml`) through the harness, validating actual third-party protocols against
the channel — not just the scaffold and the lang-tour fixture.

- **Blocked on** the `trix test` expect `@`-prefix fix (workstream 1 of
  `dx-e2e-findings-followups.md`) for the round-trip half to pass; until then it can run
  `check` + `build` on a protocol fixture (still useful coverage), or bracket the round-trip
  as an `xfail` like `01` does.
- **Scope:** offline (uses the local devnet); pick a representative protocol (or
  parametrize over several) and copy it into the journey workdir so the run is hermetic.

## Sequencing

1. `03-codegen-consume` Phase A — most self-contained (Node only), highest coverage/effort
   ratio; do first.
2. `06-protocol-fixture` (check/build slice) — cheap once a fixture is chosen; promote its
   round-trip when the `trix test` fix lands.
3. `03` Phase B (round-trip) — after Phase A, reuses `01`'s devnet path.
4. `05-live-network` — independent; needs the secrets job wired up (reuse the SDK e2e
   secrets). Lower urgency, higher value for release confidence.
5. `04-registry` — last; the heaviest infra/auth lift.

## Verification

- Each journey is green in isolation (`./e2e/run.sh --journey <name> --verbose`) and in the
  full suite, and passes the `add-e2e-journey` skill's Safety Checks (syntax, hermeticity —
  no stray `dolos`, no `~/.tx3/default` repoint).
- `03`: generated client dir populated and compiles; (Phase B) tx invokes against devnet.
- `04`: `trix use` resolves the published interface and the interface tx invokes.
- `05`: a real testnet submission succeeds via the Demeter endpoint (secrets present).
- `06`: a `protocols/<name>` fixture passes `check`/`build` (and the round-trip once unblocked).
- `e2e/README.md`'s journey table is updated as each lands; this plan's workstream is checked off.
