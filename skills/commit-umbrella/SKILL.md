# Commit Umbrella Skill

## Purpose
Commit — and push straight to `main` — the `toolchain` umbrella after submodule pointers have moved.
Three pre-flight checks keep the umbrella from recording a pointer other clones can't resolve, that
lags upstream, or that contradicts the routing docs:

1. **Pushed** — every pinned commit is reachable on its remote.
2. **Tracks `main`** — every pinned commit matches its upstream branch tip.
3. **Routing** — every `.gitmodules` path is documented in the right grouping `AGENTS.md`.

Each check is a script in this folder, run from the umbrella root, exiting non-zero on a problem:
[`check-pushed.sh`](./check-pushed.sh) · [`check-tracking.sh`](./check-tracking.sh) ·
[`check-routing.sh`](./check-routing.sh).

## Prerequisites
- Run from the umbrella repo root, submodules initialized (`git submodule update --init`).
- `git` with submodule support and network access to each submodule's remote (the checks fetch).

## Procedure

### 1. Snapshot
```bash
git submodule status   # which moved; +/-/U = dirty / uninitialized / conflict
git status --short
```

### 2. Run the three checks
```bash
bash skills/commit-umbrella/check-pushed.sh     # Check 1
bash skills/commit-umbrella/check-tracking.sh   # Check 2
bash skills/commit-umbrella/check-routing.sh    # Check 3
```
Resolve before committing:
- **Check 1 `FAIL` / `DIRTY`** — local-only commits or uncommitted changes. Push (or commit/stash) the
  submodule first, else the recorded pointer is unresolvable for everyone else.
- **Check 2 `BEHIND`** — upstream `main` moved past the pin. Fast-forward to the tip (the usual intent)
  or confirm with the user you mean to pin an older commit.
- **Check 2 `DIVERGED`** — the pin isn't in `origin/main`'s history. Submodule PRs are **squash-merged**
  (a fresh SHA on `main`; the feature commits never become ancestors), so a *merged* branch still reports
  `DIVERGED`. **Verify merge state with `gh pr view <n> --json state,mergedAt` — never the SHA.** If
  merged: fast-forward the submodule to `origin/main` and pin that tip. If open: stop and wait.
- **Check 3 `FAIL`** — add the submodule's routing line to its grouping `AGENTS.md`. Then skim each
  grouping's "Routing a change" list for stale entries the script can't catch (it tolerates non-submodule
  subdirs like `sdks/sdk-spec`).

### 3. Commit and push to `main`
Umbrella changes go straight to `main` — no feature branch, no PR. Once the checks pass (or the user
approved each exception), stage **only** this release's submodules:
```bash
git add <moved-submodule-paths>
git commit -m "chore: bump submodules to latest main"   # name what moved
git push origin main
```
Keep `manifest-*.json` edits in their own commit — that's `channel-version-update`, not this skill.

## Guardrails
- **Don't auto-resolve `BEHIND` / `DIVERGED`.** Surface them; let the user decide. Committing unmerged
  submodule work to the umbrella `main` is almost never intended.
- **`DIVERGED` ≠ unmerged — verify the PR, not the SHA.** Squash-merge flags every merged branch as
  `DIVERGED`; confirm via `gh pr`, then pin the `origin/main` tip, never the orphaned feature commit.
- **Scope to this release.** Stage only moved submodules; surface unrelated drift, don't fast-forward it.
- **Routing fixes are in scope; manifest edits are not** (separate commit).

## Safety Checks
- [ ] Checks 1–3 pass (or each exception user-approved).
- [ ] No moved submodule has unpushed commits or a dirty worktree.
- [ ] Any `DIVERGED` submodule's merge was confirmed via `gh pr` and repinned to the `origin/main` tip.
- [ ] Only this release's submodules staged; manifest edits committed separately.

## Error Handling
- **`fetch failed`** — check network / SSH to that remote; the checks are unreliable without a fresh fetch.
- **Uninitialized (`-`)** — `git submodule update --init <path>` first.
- **Conflict (`U`)** — resolve the submodule conflict before committing the umbrella.
