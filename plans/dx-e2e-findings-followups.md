# Plan: DX e2e harness — findings follow-ups

Status: **open / not started** — the harness is in place (`e2e/`); these are the
fixes for what it surfaced on first run.
Scope: `tooling/trix` (the `test` expect path), `lang/tx3` (TIR lowering perf),
and the `e2e/` harness itself (xfail promotion + future journeys).
Origin: the umbrella DX e2e harness landed 2026-06-16 (`e2e/run.sh`, journeys
`01-basic-init` and `02-lang-tour`). Running it against the installed beta
toolchain (trix 0.26.0 / tx3c 0.22.0 / dolos 1.2.0 / cshell 0.14.0) — and
cross-checking stable (trix 0.25.1 / tx3c 0.21.0) — produced two findings,
recorded in `e2e/README.md` (§ Findings) and worth fixing upstream.
Related: [`e2e/README.md`](../e2e/README.md) and the memory note
`trix-test-expect-at-prefix-bug`.

## Context

The harness drives the real `trix`/`tx3c`/`dolos`/`cshell` binaries through a
developer's journey — interop no single submodule's tests cover. Two journeys
exist today: `01-basic-init` (default scaffold → offline devnet round-trip) and
`02-lang-tour` (a feature-dense `main.tx3` pushed through `check → build →
inspect tir`). The first runs of both immediately exposed one correctness bug
and one performance smell. Neither blocks the harness (journey 01 brackets the
bug as an `xfail`; journey 02 still passes), but both are real and tracked here
so they aren't lost.

## Workstreams

### 1. Fix `trix test` balance assertions (`@`-prefix not stripped)

`trix test` resolves and submits the scaffolded transfers fine, but its
expect/balance phase errors with `CShell failed to get wallet utxos`.
**Root cause** (unambiguous in the code): `tooling/trix/src/commands/expect.rs`
(~line 20) calls `cshell::wallet_utxos(test_home, &expect.from)` with the literal
placeholder `"@bob"`, while cshell wallets are named `bob` (no `@`). The
transaction path already strips the `@` (`tooling/trix/src/commands/test.rs`,
`replace_placeholder_args`); the expect path does not.
`tooling/trix/src/spawn/cshell.rs` `wallet_utxos` then shells out to
`cshell wallet utxos "@bob" …`, which exits non-zero. Reproduces identically on
**stable** (trix 0.25.1) and **beta** (0.26.0), so it is not a regression.

Secondary bug in the same path: `trix test` **leaks its Dolos daemon** when the
expect phase errors — `expect::expect_utxo(...)?` returns via `?` before
`devnet.daemon.kill()` in `commands/test.rs`. (The e2e runner reaps it as a
workaround; the leak should still be fixed.)

The fix:
- strip the leading `@` before the cshell call in `expect_utxo` (mirror
  `replace_placeholder_args`), e.g. resolve `expect.from.trim_start_matches('@')`
  — or better, resolve it to the wallet name the same way the tx path does;
- run the devnet teardown unconditionally (move `daemon.kill()` past the expect
  step, or wrap the body so the daemon is killed on the error path too);
- add a trix unit/e2e test that asserts the expect path queries `bob`, not
  `@bob`.

Once shipped, the `01-basic-init` round-trip stops matching the xfail signature
and `xfail_cmd` prints an **XPASS** nudge — at that point promote the step in
`e2e/journeys/01-basic-init/journey.sh` back to a strict
`run_cmd … trix test …` + `assert_output_contains "Test Passed"` and drop the
xfail.

### 2. Investigate feature-dense compile/lower latency

On the `02-lang-tour` fixture (~70 lines), `trix build` and `trix inspect tir`
each take **~14s**, versus sub-second for the basic transfer. The emitted TIR
shows the `source` input-resolution expression
(`EvalParam.ExpectInput["source", { … }]`) re-embedded **dozens of times** — once
per `source.fieldN` access and per element of the `...source` record spread in
`output named_output`. This looks like the lowering/reduction expands the input
resolution combinatorially instead of resolving it once and referencing it.

The goal: profile `tx3c` build + lower on the `02-lang-tour` fixture and remove
the blow-up — likely common-subexpression / memoization of an input's resolved
representation so property accesses and spreads reference a single resolved node
rather than re-deriving the full `ExpectInput` each time. The work is in
`lang/tx3` — the analyze→lower passes in `crates/tx3-lang` and the Cardano
lowering in `crates/tx3-cardano` (confirm which pass duplicates the node before
choosing where to fix). Validate the TIR is semantically unchanged (the resolver
must still see the same effective values).

### 3. Harden the harness around these findings

Small, harness-local follow-ups that the findings motivate:
- **CI cadence for slow journeys.** `02-lang-tour` is ~31s today (≈ workstream 2);
  until that lands, consider running the slower coverage journeys on a separate
  cadence/job from the fast `01` gate (the runner already supports `--journey`).
- **Promotion checklist.** When workstream 1 ships, flip journey 01's xfail
  (above) and update `e2e/README.md` § Findings + the memory note.
- **Keep the lang-tour fixture current.** `02-lang-tour/main.tx3` tracks the
  language surface; refresh it from `lang/tx3/examples/lang_tour.tx3` when new
  constructs land so coverage doesn't rot (note: it may outpace older channels'
  `tx3c`).

## Sequencing

1. Workstream 1 (trix expect fix + daemon teardown) — small, self-contained, and
   unblocks the headline round-trip assertion. Ship in `tooling/trix`, bump the
   pointer, then promote journey 01's xfail.
2. Workstream 2 (lowering perf) — independent; needs a profiler pass in `lang/tx3`
   before a fix shape is chosen. Larger and lower-urgency than 1.
3. Workstream 3 — fold in alongside 1 and 2 as each lands.

## Verification

- §1: a fixed trix makes `trix test` on the default scaffold print `Test Passed`
  and exit 0; the `01-basic-init` round-trip step, once promoted to strict, stays
  green; no Dolos daemon survives a failed/early-exiting `trix test` (the runner's
  post-journey reap finds nothing to kill). Add a trix test for the `@`-strip.
- §2: re-run `./e2e/run.sh --journey 02-lang-tour --verbose`; `trix build` and
  `trix inspect tir` drop from ~14s toward the basic-transfer baseline, with
  byte-identical (or provably equivalent) TIR. Consider a soft time budget in the
  journey once the target is known.
- §3: the fast gate and the slower coverage journeys run on their intended
  cadences; `e2e/README.md` § Findings and the memory note reflect the shipped
  fixes.
