# Commit Umbrella Skill

## Purpose
Safely commit the `toolchain` umbrella repository after submodule pointers have moved.
Before committing, this skill runs three pre-flight checks so the umbrella never records a
pointer that other clones can't resolve, lags behind upstream, or contradicts the routing docs:

1. **Submodules have pushed their changes** — every pinned commit is reachable on its remote.
2. **Submodules track latest `main`** — every pinned commit matches the tip of its upstream branch.
3. **Routing in grouping `AGENTS.md` files is up to date** — every submodule in `.gitmodules`
   is documented, and no stale entries remain.

## Prerequisites
- Run from the umbrella repo root (the directory containing `.gitmodules` and the root `AGENTS.md`).
- `git` with submodule support; network access to each submodule's remote (for `fetch`).
- The umbrella's submodules are initialized (`git submodule update --init` if any show `-` in status).

## Context
- **`.gitmodules`** — source of truth for the submodule list: `path`, `url`, and optional `branch`
  (defaults to the remote's default branch, normally `main`) per submodule.
- **Grouping folders** — `core/`, `lang/`, `tooling/`, `plugins/`, `backends/`, `protocols/`,
  `sdks/`, each with an `AGENTS.md` that routes per-submodule. `registry/`, `docs/` are routed
  directly from the root [`AGENTS.md`](../../AGENTS.md).
- **Pinned commit** — the submodule SHA recorded (or about to be staged) in the umbrella. Read it
  with `git submodule status` (a `+` prefix means the checked-out commit differs from the staged
  pointer; a `-` means uninitialized; `U` means a conflict).
- **Check scripts** — the three checks are implemented as bash scripts in this skill folder, each
  runnable from the umbrella root and exiting non-zero when it finds a problem:
  - [`check-pushed.sh`](./check-pushed.sh) — Check 1
  - [`check-tracking.sh`](./check-tracking.sh) — Check 2
  - [`check-routing.sh`](./check-routing.sh) — Check 3

## Procedure

### 1. Snapshot submodule state
```bash
git submodule status
git -C . status --short
```
Note which submodules moved (these become the umbrella commit) and which show `+`/`-`/`U` prefixes.

### 2. Check 1 — submodules have pushed their changes
Confirm every submodule's pinned commit exists on its remote (the script fetches first so
remote-tracking refs are current, then checks reachability, and also flags dirty worktrees and
conflicts):
```bash
bash skills/commit-umbrella/check-pushed.sh
```
Any `FAIL` means there are local-only commits. **Stop** and push that submodule (or have the
author push) before committing the umbrella — otherwise the recorded pointer is unresolvable for
anyone else. `DIRTY` means uncommitted changes — the pointer is provisional; commit or stash first.

### 3. Check 2 — submodules track latest `main`
Compare each submodule's pinned commit to the tip of its upstream branch. The script resolves the
branch from `.gitmodules` (`branch` field), falling back to the remote's default branch:
```bash
bash skills/commit-umbrella/check-tracking.sh
```
- `OK` — good.
- `BEHIND` — upstream `main` has moved past the pinned commit. Decide with the user whether to fast-forward
  to the tip before committing (usual intent for an umbrella bump) or intentionally pin an older commit.
- `DIVERGED` — the submodule is on a feature branch or points at work not yet merged to `main`
  (the `git submodule status` listing shows the branch/tag name). **Stop**: the umbrella's `main`
  should not record unmerged submodule work unless the user explicitly wants that. Ask.

### 4. Check 3 — routing in grouping `AGENTS.md` is up to date
Verify each submodule `path` in `.gitmodules` is documented in the right doc. A submodule under
`<group>/…` must appear in `<group>/AGENTS.md`; `registry/` and `docs/` must appear in the root
`AGENTS.md`:
```bash
bash skills/commit-umbrella/check-routing.sh
```
Then check the reverse manually — routing entries that no longer have a matching submodule (stale
rows left behind by a removed submodule). The script does not automate this because grouping docs
legitimately reference non-submodule subdirectories (e.g. `sdks/scripts`, `sdks/sdk-spec`); skim
each grouping `AGENTS.md` "Routing a change" section against the `.gitmodules` paths for that group.

Any `FAIL` or stale entry means the routing docs are out of sync. **Fix the relevant `AGENTS.md`**
(add the new submodule's routing line in the grouping's "Routing a change" list, matching the
existing format; remove stale lines) before committing. The root `AGENTS.md` grouping summary and
the per-group `AGENTS.md` should both reflect added/removed submodules.

### 5. Stage and commit
Once all three checks pass (or the user has approved each exception):
```bash
git add -A
git commit -m "chore: bump submodules to latest main"
```
Use a commit message that names what moved. For routine syncs the convention in this repo is
`chore: bump submodules to latest main` (see history); for a targeted change, describe it
(`chore: add <name> protocol submodule, bump registry to latest main`). Keep manifest edits in
their own commits (see root `AGENTS.md`).

### 6. Push
Only when the user asks to push:
```bash
git push origin <branch>
```

## Decision Guidelines
- **Don't auto-resolve `DIVERGED`/`BEHIND`.** Surface them and let the user decide whether to
  fast-forward, leave the pin, or wait for an upstream merge. Committing unmerged submodule work to
  the umbrella `main` is almost never intended.
- **Routing fixes are in scope.** If Check 3 fails because a submodule was added/removed, update the
  grouping `AGENTS.md` (and root summary) as part of this commit — that's the whole point of the check.
- **Scope discipline.** This skill commits submodule-pointer and routing-doc changes. It does not
  touch `manifest-*.json` (that's `channel-version-update`) — keep those in separate commits.

## Safety Checks
- [ ] No moved submodule has unpushed commits (Check 1 all `OK`).
- [ ] No moved submodule is dirty (uncommitted working-tree changes).
- [ ] Each submodule is at — or intentionally pinned relative to — its upstream branch tip (Check 2).
- [ ] No submodule pins unmerged feature-branch work without explicit user approval.
- [ ] Every `.gitmodules` path is documented and no stale routing entries remain (Check 3).
- [ ] Manifest changes, if any, are committed separately.

## Error Handling
- **`fetch failed`** — check network / SSH access to that submodule's remote; the push/track checks
  are unreliable without a fresh fetch.
- **Uninitialized submodule (`-` prefix)** — run `git submodule update --init <path>` before checking.
- **Conflict (`U` prefix)** — resolve the submodule conflict first; do not commit the umbrella over it.
