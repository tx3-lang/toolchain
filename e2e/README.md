# DX end-to-end tests

These tests validate the **developer experience of the assembled toolchain**: that a
developer who installs a channel and follows the normal flow (`init → check → build → test`)
actually gets a working result. They exercise the real `trix`, `tx3c`, `dolos`, and `cshell`
binaries together — interop that no single submodule's own tests cover. This is the umbrella's
job, because only it knows the full channel composition (the `manifest-*.json` files) and is where
releases are cut.

This is deliberately *not* a duplicate of `tooling/trix/tests/e2e/`, which covers `trix init`
structurally inside the trix crate. Here we cover the **runtime** journey against real
helper binaries.

## Layout

```
e2e/
├── run.sh                       # entrypoint: resolve binaries, run journeys, summarize
├── lib/common.sh                # logging + fail-fast assertion helpers
└── journeys/
    └── <NN>-<name>/
        ├── journey.sh           # the journey script (sources lib/common.sh, drives trix)
        ├── README.md            # what this journey covers, its scope, and any caveats
        └── <fixtures>           # optional per-journey fixtures (e.g. a main.tx3)
```

A **journey** is a self-contained script that sources `lib/common.sh` and drives `trix`
with the assertion helpers. `run.sh` discovers every `journeys/*/journey.sh`, runs each in
an isolated temp working directory, and prints a markdown pass/fail summary, exiting
non-zero if any journey fails. **Each journey documents itself in its own `README.md`** — this
top-level README only describes the harness.

## Channel-aware journeys

A journey's fixture may use language features newer than an older channel's `tx3c`. A journey
declares the minimum it needs with a header comment in its `journey.sh`:

```sh
#@ min-tx3c: 0.22.0
```

The runner reads the `tx3c` under test and **skips** (does not fail) any journey whose floor isn't
met, exiting 0. The gate is version-based so it **auto-heals**: when a feature graduates to an older
channel (its `tx3c` bumps past the floor), the journey starts running there with no edit.

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

Prerequisites: `bash`, `git`, and the toolchain reachable in your chosen mode. No journey needs
secrets or a live network beyond the one-time install — runtime journeys run entirely on a local
Dolos devnet with deterministic cshell wallets.

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
./e2e/run.sh --journey <name> --verbose
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
the native runners (`ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`). The `stable` job runs the
broad-coverage journeys; the `beta` job cherry-picks the ones exercising features (or fixes) that
only beta has yet. The per-job journey lists live in the workflow itself.

Compat lives in one place — the journey's `#@ min-tx3c` header, enforced by the runner's skip gate —
so the workflow needs no per-cell compat config. The shared per-cell steps (install via tx3up, cache
`~/.tx3/<channel>`, run one journey) live in the composite action `.github/actions/dx-e2e-run`.
Native runners only: a DX test must validate the real per-platform install, which a Linux container
would misrepresent (and drop macOS). Triggers: pushes to `main` touching `manifest-*.json` /
`e2e/**` / the workflow / the action; a nightly schedule; manual dispatch.

Journeys that need secrets (live network) would run in a separate, secrets-gated job.

## Adding a journey

See the **`add-e2e-journey` skill** (`skills/add-e2e-journey/SKILL.md`) — the canonical guide for
the journey contract, the `lib/common.sh` helper API, fixtures, and capability gating. In brief: add
a `journeys/<NN>-<name>/` directory with a `journey.sh` that sources `${E2E_LIB}` and drives
`"${TRIX}"`, plus a `README.md` describing it, and `run.sh` discovers it automatically. Adding,
removing, or modifying a journey is self-contained to its folder (and the workflow's journey list) —
it should not touch this README.

Planned journeys to grow coverage are tracked in
[`plans/dx-e2e-journey-roadmap.md`](../plans/dx-e2e-journey-roadmap.md).

## Hermeticity

After each journey the runner reaps any `dolos` process it spawned (matched by the run's unique
workdir), so a devnet daemon never outlives the journey that started it, and it warns at startup if
the devnet ports (8164/5164) are already in use. Channel mode never runs `tx3up use`, so it never
repoints your active channel.
