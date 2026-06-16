# DX end-to-end tests

These tests validate the **developer experience of the assembled toolchain**: that a
developer who installs a channel and follows the normal journey
(`init → check → build → test`, including a real local devnet round-trip) actually gets a
working result. They exercise the real `trix`, `tx3c`, `dolos`, and `cshell` binaries
together — interop that no single submodule's own tests cover. This is the umbrella's job,
because only it knows the full channel composition (the `manifest-*.json` files) and is where
releases are cut.

This is deliberately *not* a duplicate of `tooling/trix/tests/e2e/`, which covers `trix init`
structurally inside the trix crate. Here we cover the **runtime** journey against real
helper binaries.

## Layout

```
e2e/
├── run.sh                          # entrypoint: resolve binaries, run journeys, summarize
├── lib/common.sh                   # logging + fail-fast assertion helpers
└── journeys/
    ├── 01-basic-init/journey.sh    # init → check → build → test (offline devnet round-trip)
    └── 02-lang-tour/
        ├── journey.sh              # init → swap in feature-dense main.tx3 → check → build → inspect tir
        └── main.tx3                # feature-dense fixture (a copy of the lang's lang_tour example)
```

A **journey** is a self-contained script that sources `lib/common.sh` and drives `trix`
with the assertion helpers. `run.sh` discovers every `journeys/*/journey.sh`, runs each in
an isolated temp working directory, and prints a markdown pass/fail summary, exiting
non-zero if any journey fails.

The two journeys cover complementary axes:

| Journey | Covers | Scope |
|---------|--------|-------|
| **01-basic-init** | the default scaffold end to end, including a real devnet round-trip (trix + tx3c + dolos + cshell + resolver) | runtime |
| **02-lang-tour** | the breadth of the language surface — env, records/variants, lists/maps/tuples, policies/assets, spread, locals, and the full Cardano construct set — pushed through `check → build → inspect tir` | compile/lower |

`02-lang-tour` is compile/lower only: its feature-dense tx references hard-coded UTxOs, mints,
and plutus scripts, so it can't resolve against a fresh devnet (the round-trip lives in 01). Its
fixture tracks current language features, so it may outpace an older channel's `tx3c`.

## Which binaries get tested

`run.sh` picks the binary source — `trix` resolves its helper binaries (`tx3c`, `dolos`,
`cshell`) from the tx3up install at `~/.tx3/default/bin`, or from per-tool `TX3_<TOOL>_PATH`
overrides (see `tooling/trix/src/home.rs`). The runner uses that contract:

| Mode | Command | What it validates |
|------|---------|-------------------|
| **channel** | `./e2e/run.sh --channel stable` | A released channel — black-box, exactly what ships. Installs via tx3up. |
| **local** | `./e2e/run.sh --local` | Locally-built / unreleased binaries, via `TX3_TRIX_PATH` + `TX3_{TX3C,DOLOS,CSHELL}_PATH` (or PATH). Never touches `~/.tx3`. |
| **default** | `./e2e/run.sh` | Whatever `trix` is already on your PATH. |

In **channel** mode, local runs isolate the install under a throwaway `$HOME` so they never
clobber your real `~/.tx3` (both tx3up and trix root at `~/.tx3`, and `dirs::home_dir()`
respects `$HOME` on Unix). CI runners are already ephemeral, so they pass `--no-isolate`.

## Running locally

Prerequisites: `bash`, `git`, and the toolchain reachable in your chosen mode. The basic
journey needs **no secrets and no network** beyond the one-time install — the devnet round-trip
runs entirely on a local Dolos devnet with deterministic cshell wallets.

```sh
# Test the toolchain you already have installed:
./e2e/run.sh

# Install + test a specific channel (requires tx3up; isolates ~/.tx3 by default):
./e2e/run.sh --channel beta

# Test locally-built binaries (e.g. from cargo build in each submodule):
TX3_TRIX_PATH=/path/to/trix \
TX3_TX3C_PATH=/path/to/tx3c \
TX3_DOLOS_PATH=/path/to/dolos \
TX3_CSHELL_PATH=/path/to/cshell \
  ./e2e/run.sh --local

# Run one journey with live output:
./e2e/run.sh --journey 01-basic-init --verbose
```

Install `tx3up` (only needed for `--channel`) with the bootstrap script:

```sh
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/tx3-lang/tx3up/releases/latest/download/tx3up-installer.sh | sh
```

On failure, `run.sh` preserves the per-journey working directory and a `<journey>.log` under
its temp run-root (path printed at the end), and `--artifacts-dir <dir>` copies them somewhere
stable for CI upload.

## CI

`.github/workflows/dx-e2e.yml` runs the harness in **channel** mode on the native matrix
(`ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`) — native because a DX test must validate
the real per-platform install experience, which a Linux container would misrepresent (and drop
macOS entirely). It triggers on:

- pushes to `main` that touch `manifest-*.json` — gate that the channel being shipped works;
- a nightly schedule — catch drift in already-released channels / upstream services;
- manual dispatch with a `channel` input.

The basic journey needs no secrets. Future live-network journeys would run in a separate,
secrets-gated job.

## Adding a journey

See the **`add-e2e-journey` skill** (`skills/add-e2e-journey/SKILL.md`) — the canonical guide for
the journey contract, the `lib/common.sh` helper API, fixtures, and `xfail`. In brief: add a
`journeys/<NN>-<name>/journey.sh` that sources `${E2E_LIB}` and drives `"${TRIX}"` with the
assertion helpers, and `run.sh` discovers it automatically.

Planned journeys to grow coverage are tracked in
[`plans/dx-e2e-journey-roadmap.md`](../plans/dx-e2e-journey-roadmap.md).

## Findings (what this test has already surfaced)

A DX test is also a friction detector. The first journey immediately found a real, reproducible
toolchain bug:

- **`trix test` balance assertions are broken (`xfail` in journey 01).** `trix test` resolves and
  submits the scaffolded transfers fine, but its expect phase calls
  `cshell wallet utxos "@bob"` — passing the literal `@`-prefixed placeholder instead of the
  wallet name `bob`. The transaction path strips the `@` (`tooling/trix/src/commands/test.rs`,
  `replace_placeholder_args`); the expect path does not
  (`tooling/trix/src/commands/expect.rs:20`). cshell then errors with `CShell failed to get
  wallet utxos`. Reproduces on both **stable** (trix 0.25.1) and **beta** (0.26.0). One-line fix
  in trix: strip the leading `@` before the cshell call. The journey marks this step `xfail` with
  that signature, so it auto-promotes to a hard failure the moment trix is fixed.

- **Feature-dense compile/lower is slow.** On the `02-lang-tour` fixture, `trix build` and
  `trix inspect tir` each take ~14s (vs. sub-second for the basic transfer). The TIR shows the
  `source` input resolution re-embedded dozens of times — the record spread (`...source`) plus
  repeated `source.fieldN` accesses look like they expand combinatorially in lowering. Worth a
  profiler pass in `tx3c`/`tx3-cardano`. (The journey still passes; this is a latency observation.)

Other things worth watching as journeys grow:

- The `trix init` template (`tooling/trix/templates/tx3/test.toml.tpl`) is the source of truth for
  the test shape — it matches the `Test` parser. The `tooling/trix/examples/test/` fixture uses a
  different, non-parsing shape; don't copy from it.
- **Time-to-first-green** — devnet startup + block intervals dominate the `trix test` step (~15s).
- Command output strings the assertions match on (`"check passed"`, `"Dolos daemon started"`).

## Hermeticity

`trix test` leaks its Dolos devnet daemon when its expect phase errors (it returns before the
`daemon.kill()`), so the runner reaps any dolos process it spawned (matched by the run's unique
workdir) after each journey, and warns at startup if the devnet ports (8164/5164) are already in
use. Channel mode never runs `tx3up use`, so it never repoints your active channel.
