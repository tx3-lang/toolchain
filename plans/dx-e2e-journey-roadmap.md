# Plan: DX e2e harness — journey roadmap

Status: **open / not started** — candidate journeys to grow coverage beyond what
ships today (`01-basic-init` offline gate, `02-lang-tour` + `03-lang-edge`
language coverage, `04-devnet-roundtrip` runtime round-trip).
Scope: the `e2e/` harness (new `journeys/<NN>-<name>/`), plus the surfaces each
journey exercises — `trix codegen` + an SDK (`sdks/`), the registry
(`services/registry`), live TRP endpoints, and the `protocols/` fixtures.
Related: [`e2e/README.md`](../e2e/README.md) and the `add-e2e-journey` skill
(`skills/add-e2e-journey/SKILL.md`) — the canonical guide for actually authoring a
journey.

## Context

Each journey is a self-contained folder (`journey.sh` + a `README.md` + optional
fixtures) that drives the real `trix` binary through one developer scenario and
asserts the outcome; `e2e/run.sh` discovers `journeys/*/journey.sh`
automatically. Today's journeys cover the offline scaffold gate (`01`), the
*compile/lower* breadth and edge of the language surface (`02`, `03`), and the
*runtime* devnet round-trip on the default scaffold (`04`). The journeys below
extend coverage outward along the developer path — codegen, registry, live
networks, real protocols.

The names below are themes, **not** fixed IDs — assign the `<NN>-` prefix when you
author each one (next free number is `05`). Author with the `add-e2e-journey`
skill: it owns the journey contract, the `lib/common.sh` helper API, fixtures,
capability gating, and the per-journey `README.md` convention. This plan only
defines *what* each journey should exercise.

## Workstreams

### codegen-consume — generated client compiles (and invokes)

Exercise the `trix codegen` → generated SDK path that nothing in the harness
touches yet. Scaffold, `trix codegen --plugin ts-client`, then compile the
generated TypeScript client to prove the codegen output is well-formed against the
project's TII.

- **Phase A (offline, no devnet):** generate + typecheck/compile the client. The
  ts-client templates come from `tx3-lang/web-sdk` (`.trix/client-lib`); assert the
  output dir is populated and `tsc`/build succeeds. This is the cheap, high-value core.
- **Phase B (round-trip):** import the generated client in a tiny host script and
  invoke a tx against the local devnet (or `--skip-submit` to validate unsigned-CBOR
  build). Reuses `04-devnet-roundtrip`'s devnet machinery.
- **Deps/CI:** adds a Node toolchain (`actions/setup-node`) — still no secrets, so it
  can ride the matrix once Node is provisioned. Consider a separate job to keep the
  no-Node journeys minimal.

### registry — publish → use → invoke an interface

Exercise the protocol-reuse path: `trix publish` a protocol to a registry, then in a
separate consumer project `trix use <scope>/<name>:<ver>` and invoke the interface tx.

- **Needs infra:** an OCI registry (`oci.tx3.land`, or a throwaway local registry the
  journey stands up) plus publish auth (OIDC / GitHub App attestation — see
  `tooling/trix/src/commands/publish.rs` and `interfaces/`). The publish + trust-pin
  flow is the hard part; a local registry fixture keeps it hermetic.
- **Scope:** registry-dependent; gate it in a job with whatever registry/auth it needs.
  A reduced first cut can publish to a local registry and `use` it without live OIDC.

### live-network — preview/preprod invoke (secrets-gated)

Invoke a real transfer against a live Cardano testnet (preview/preprod) via a Demeter
TRP endpoint — the only journey that leaves the local devnet.

- **Reuse:** mirror the existing SDK e2e harness `sdks/scripts/run-e2e-tests.sh` and its
  env contract (`TRP_ENDPOINT_PREPROD`, `TRP_API_KEY_PREPROD`, funded test wallets
  `TEST_PARTY_A/B_*`). Use the same GitHub secrets.
- **Scope:** **secrets-gated, separate CI job** — never on the fast offline gate. Likely
  `--profile preview`/`preprod` with funded identities; assert on the submitted tx /
  resolver response rather than balances (testnet timing).

### protocol-fixture — a real protocol through `trix test`

Run a real protocol from `protocols/<name>/` (each ships `trix.toml` + `main.tx3` +
`tests/basic.toml`) through the harness, validating actual third-party protocols against
the channel — not just the scaffold and the lang fixtures.

- **Round-trip dependency:** the `trix test` expect/balance fix is merged
  (tx3-lang/trix#123) but not yet in a released channel, so the round-trip half fails on
  released binaries — exactly like `04-devnet-roundtrip`. Until a channel ships it, run
  `check` + `build` on a protocol fixture (still useful coverage), or keep the round-trip
  strict and accept the red (as `04` does).
- **Scope:** offline (uses the local devnet); pick a representative protocol (or
  parametrize over several) and copy it into the journey workdir so the run is hermetic.

## Sequencing

1. `codegen-consume` Phase A — most self-contained (Node only), highest coverage/effort
   ratio; do first.
2. `protocol-fixture` (check/build slice) — cheap once a fixture is chosen; add the
   round-trip when the `trix test` fix releases.
3. `codegen-consume` Phase B (round-trip) — after Phase A, reuses `04`'s devnet path.
4. `live-network` — independent; needs the secrets job wired up (reuse the SDK e2e
   secrets). Lower urgency, higher value for release confidence.
5. `registry` — last; the heaviest infra/auth lift.

## Verification

- Each journey is green in isolation (`./e2e/run.sh --journey <name> --verbose`) and in the
  full suite, and passes the `add-e2e-journey` skill's Safety Checks (syntax, hermeticity —
  no stray `dolos`, no `~/.tx3/default` repoint).
- `codegen-consume`: generated client dir populated and compiles; (Phase B) tx invokes against devnet.
- `registry`: `trix use` resolves the published interface and the interface tx invokes.
- `live-network`: a real testnet submission succeeds via the Demeter endpoint (secrets present).
- `protocol-fixture`: a `protocols/<name>` fixture passes `check`/`build` (and the round-trip once released).
- Each new journey ships its own `README.md`; this plan's workstream is checked off as it lands.
