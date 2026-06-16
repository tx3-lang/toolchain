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
    ├── 01-basic-init/journey.sh        # init → check → build (offline scaffold validation)
    ├── 02-lang-tour/
    │   ├── journey.sh                  # init → swap in feature-dense main.tx3 → check → build → inspect tir
    │   └── main.tx3                    # feature-dense fixture (a copy of the lang's lang_tour example)
    ├── 03-lang-edge/                   # newest lang features (functions, operators, tuples, doc-comments)
    └── 04-devnet-roundtrip/journey.sh  # init → test (real devnet round-trip: trix + tx3c + dolos + cshell)
```

A **journey** is a self-contained script that sources `lib/common.sh` and drives `trix`
with the assertion helpers. `run.sh` discovers every `journeys/*/journey.sh`, runs each in
an isolated temp working directory, and prints a markdown pass/fail summary, exiting
non-zero if any journey fails.

The journeys cover complementary axes:

| Journey | Covers | Scope |
|---------|--------|-------|
| **01-basic-init** | the default scaffold through `init → check → build` — the fast, fully offline gate | compile/lower |
| **02-lang-tour** | the breadth of the language surface — env, records/variants, lists/maps/tuples, policies/assets, spread, locals, and the full Cardano construct set — pushed through `check → build → inspect tir` | compile/lower |
| **03-lang-edge** | the *newest* language additions — user-defined functions, the `*`/`/` operators, parametric tuples (literals + indexing), and `///` doc-comments — pushed through `check → build → inspect tir` (needs tx3c ≥ 0.22) | compile/lower |
| **04-devnet-roundtrip** | a real devnet round-trip on the default scaffold (`trix test`) — spins a local Dolos devnet, restores cshell wallets, submits the scaffolded transfers, asserts balances; exercises trix + tx3c + dolos + cshell + resolver together | runtime |

`02-lang-tour` is compile/lower only: its feature-dense tx references hard-coded UTxOs, mints,
and plutus scripts, so it can't resolve against a fresh devnet (the round-trip lives in
`04-devnet-roundtrip`).

## Channel-aware journeys

A journey's fixture may use language features newer than an older channel's `tx3c` (e.g.
`02-lang-tour` uses tuples, which need tx3c ≥ 0.22 — present on `beta`, not `stable`). A journey
declares its floor with a header comment:

```sh
#@ min-tx3c: 0.22.0
```

The runner reads the `tx3c` under test and **skips** (does not fail) any journey whose floor isn't
met — `./e2e/run.sh --channel stable` runs `01-basic-init` and skips `02-lang-tour`, exiting 0.
The gate is version-based so it **auto-heals**: when a feature graduates to `stable` (its `tx3c`
bumps past the floor), the journey starts running there with no edit.

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

`.github/workflows/dx-e2e.yml` runs **one job per channel**, each an `{os × journey}` matrix over
the native runners (`ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`):

- **`stable`** — the offline scaffold gate (`01-basic-init`) plus the lang-surface journeys. Edge
  journeys whose `#@ min-tx3c` exceeds stable's `tx3c` install **skip** (green), and start running
  automatically once the feature graduates to stable (auto-heal).
- **`beta`** — the *edge-feature* journeys (the ones exercising features only on beta, like
  `02-lang-tour`'s tuples), plus `04-devnet-roundtrip`. The devnet round-trip currently **fails** on
  released channels — a known, tracked trix bug, fixed on `main` but not yet released. This is
  intentional (a real failure, not a tolerated `xfail`); the job goes green once the fix ships to
  beta, which gets the release first.

Compat lives in one place — the journey's `#@ min-tx3c` header, enforced by the runner's skip gate —
so the workflow needs no per-cell compat config. The shared per-cell steps (install via tx3up, cache
`~/.tx3/<channel>`, run one journey) live in the composite action `.github/actions/dx-e2e-run`.
Native runners only: a DX test must validate the real per-platform install, which a Linux container
would misrepresent (and drop macOS). Triggers: pushes to `main` touching `manifest-*.json` /
`e2e/**` / the workflow / the action; a nightly schedule; manual dispatch.

No journey here needs secrets. Future live-network journeys would run in a separate, secrets-gated
job.

## Adding a journey

See the **`add-e2e-journey` skill** (`skills/add-e2e-journey/SKILL.md`) — the canonical guide for
the journey contract, the `lib/common.sh` helper API, fixtures, and `xfail`. In brief: add a
`journeys/<NN>-<name>/journey.sh` that sources `${E2E_LIB}` and drives `"${TRIX}"` with the
assertion helpers, and `run.sh` discovers it automatically.

Planned journeys to grow coverage are tracked in
[`plans/dx-e2e-journey-roadmap.md`](../plans/dx-e2e-journey-roadmap.md).

## Hermeticity

After each journey the runner reaps any `dolos` process it spawned (matched by the run's unique
workdir), so a devnet daemon never outlives the journey that started it, and it warns at startup if
the devnet ports (8164/5164) are already in use. Channel mode never runs `tx3up use`, so it never
repoints your active channel.
