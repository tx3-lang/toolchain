# Add E2E Journey Skill

## Purpose
Add a new **journey** to the umbrella DX end-to-end harness (`e2e/`). A journey is a
self-contained script under `e2e/journeys/<NN>-<name>/journey.sh` that drives the real
`trix` binary (and, through it, `tx3c`/`dolos`/`cshell`) through one developer scenario and
asserts the outcome. `e2e/run.sh` discovers every `journeys/*/journey.sh` automatically, so
adding a journey is: create the directory, write the script against the shared helper API,
and verify it locally. This skill is the canonical reference for that API and procedure —
`e2e/README.md` intentionally defers to it rather than duplicating it.

## Prerequisites
- Run from the umbrella repo root with the `e2e/` harness present.
- `bash`, and the toolchain reachable in at least one mode (a `trix` on PATH for `./e2e/run.sh`,
  or `--local` / `--channel`). See `e2e/README.md` § "Which binaries get tested".
- The basic, offline journeys need no secrets and no network beyond a one-time install.

## Context

### How a journey is run
`run.sh` runs each journey as `bash journeys/<name>/journey.sh` in its **own throwaway working
directory** (CWD = a fresh temp dir, *not* the journey directory), captures pass/fail + duration,
prints a markdown summary, and exits non-zero if any journey fails. A failed assertion ends the
journey non-zero; the runner preserves that journey's workdir + log for inspection.

### The journey contract (env the runner provides)
- `TRIX` — path/name of the `trix` binary under test. **Always invoke `"${TRIX}"`**, never a bare `trix`.
- `E2E_LIB` — absolute path to `lib/common.sh`; the journey must `source` it.
- `E2E_VERBOSE` — `1` to stream command output, `0` to capture it (helpers honor this).
- `LAST_OUTPUT_FILE` — where `run_cmd`/`xfail_cmd` write the most recent command's combined output
  (what `assert_output_contains` greps). Set by the runner; don't override it.

### Helper API (`lib/common.sh`) — the single source of truth
All assertion helpers are **fail-fast**: on failure they print a clear message and `exit 1`,
which the runner records as a failed journey. So a journey reads as a linear script.

- `journey_begin "<title>" "<one-line desc>"` — banner; call once at the top after sourcing.
- `journey_end` — success marker; call once at the end.
- `run_cmd "<desc>" <cmd> [args…]` — run a command; abort the journey if it exits non-zero.
  Captures output to `LAST_OUTPUT_FILE`.
- `assert_exists <path> ["<desc>"]` — the path exists in the workdir.
- `assert_found "<desc>" <dir> <filename>` — at least one file named `<filename>` exists under `<dir>`.
- `assert_output_contains "<needle>" ["<desc>"]` — the last `run_cmd`/`xfail_cmd` output contains
  `<needle>` (case-insensitive, fixed-string).
- `xfail_cmd "<label>" "<known-failure-signature>" <cmd> [args…]` — for a step **expected to fail**
  because of a known, tracked upstream bug. Tolerates failure *only* when the output matches the
  signature (real fail on any other signature); if the command starts **succeeding**, it logs an
  `XPASS` nudge so the xfail auto-surfaces for promotion. Always assert the still-working sub-behavior
  with `assert_output_contains` afterward.
- `info` / `ok` / `warn` / `err` / `die "<msg>"` — logging + hard stop.

### Conventions
- **Numbering**: `NN-name`, zero-padded, in run order — `01-basic-init`, `02-lang-tour`, …
  Reserve `01-basic-init` as the fast, offline default gate.
- **Fixtures**: embed per-journey files in the journey directory and resolve them from the script
  via `"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"` (CWD is the throwaway workdir, not the
  journey dir). See `02-lang-tour/main.tx3`.
- **Scope**: a journey is either *runtime* (needs a working devnet round-trip, like `01`) or
  *compile/lower* (like `02`, which can't resolve against a fresh devnet). Pick one and say which
  in the banner.

## Procedure

### 1. Decide scope, number, and mode needs
Name it `<NN>-<short-kebab>`. Decide: offline (no secrets) or network/secrets-gated? Runtime
round-trip or compile/lower only? This determines the steps and the CI placement (§7).

### 2. Scaffold the journey
```bash
mkdir -p e2e/journeys/<NN>-<name>
$EDITOR e2e/journeys/<NN>-<name>/journey.sh
chmod +x e2e/journeys/<NN>-<name>/journey.sh
```
Skeleton (copy, then fill in):
```bash
#!/usr/bin/env bash
#
# Journey <NN> — <title>.
# <1–3 lines: what it covers and its scope (runtime vs compile/lower).>
#
# Run via e2e/run.sh, which provides $TRIX and an isolated working directory.

source "${E2E_LIB:?E2E_LIB not set — run this journey via e2e/run.sh}"

# Only if the journey ships fixtures:
JOURNEY_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

journey_begin "<NN>-<name>" "<one-line description of the flow>"

run_cmd "trix init -y — scaffold a new project" "${TRIX}" init -y
# … drive trix; assert after each step …

journey_end
```

### 3. Drive `trix` and assert
Use `run_cmd` for each step and an assertion after it. Match `assert_output_contains` on the
**stable human-output strings** trix prints (e.g. `"check passed"`, `"Dolos daemon started"`,
`"Test Passed"`), and `assert_found ".tx3/tii" "main.tii"` for build artifacts. Keep the script
linear — no manual `if`/exit handling; the helpers abort on failure.

### 4. Embed fixtures (if needed)
Drop fixture files in the journey directory, then in step 3 copy them into the workdir, e.g.
`cp "${JOURNEY_HOME}/main.tx3" main.tx3` after `trix init -y`. Keep fixtures self-contained so the
journey runs in every mode; refresh language-feature fixtures from the upstream example when new
constructs land.

### 5. Bracket known-broken steps with `xfail_cmd`
If a step fails because of a *tracked* upstream bug, use `xfail_cmd "<label>" "<signature>" …`
instead of `run_cmd`, then `assert_output_contains` the part that still works. Document the bug
inline (root cause + where it's tracked). The xfail auto-promotes to a hard failure once fixed.

### 6. Verify locally
```bash
bash -n e2e/journeys/<NN>-<name>/journey.sh           # syntax
./e2e/run.sh --journey <NN>-<name> --verbose          # this journey, streamed
./e2e/run.sh                                          # full suite still green
```

### 7. Place it in CI
Offline journeys ride the default `.github/workflows/dx-e2e.yml` matrix automatically (they run
once `run.sh` discovers them). Journeys that need **secrets** (live network) or are **slow** belong
in a separate job/cadence — gate them so the fast `01` gate stays quick and secret-free.

## Decision Guidelines
- **Strict vs xfail**: assert strictly by default. Reach for `xfail_cmd` *only* for a known,
  signature-stable upstream bug you've tracked (e.g. in `plans/` and a memory note) — never to
  paper over a flaky or unexplained failure.
- **Offline-first**: prefer journeys that need no secrets/network so they run on every push. Put
  anything needing Demeter keys / live endpoints in a separate secrets-gated CI job.
- **Match on stable output**: assert on the human strings trix is unlikely to reword; avoid matching
  on volatile detail (hashes, timings, file paths).
- **One scope per journey**: don't bolt a devnet round-trip onto a compile/lower journey whose tx
  can't resolve — split it.
- **Don't duplicate** `tooling/trix/tests/e2e/` (that covers `trix init` structurally in-crate); the
  umbrella journeys cover the *runtime* path against real helper binaries.

## Safety Checks
- `bash -n` passes and the script is `chmod +x`.
- The new journey is green **in isolation** (`--journey`) and in the **full suite**.
- **Hermetic**: after the run, no stray `dolos` daemon survives (`pgrep -fl 'dolos.*daemon'`) and,
  for channel mode, `~/.tx3/default` is unchanged (channel mode must never run `tx3up use`).
- Update `e2e/README.md`'s journey table/layout to list the new journey (the table is reference;
  the how-to stays here).
- If the journey brackets a new xfail, record the bug in `plans/` and a memory note so its
  promotion is tracked.
