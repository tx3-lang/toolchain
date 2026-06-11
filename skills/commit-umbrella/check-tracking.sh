#!/usr/bin/env bash
# Check 2 — every submodule's pinned commit matches the tip of its upstream branch.
# Upstream branch comes from .gitmodules (branch field), falling back to the remote's
# default branch. Run from the umbrella repo root. Exits non-zero if any submodule is
# BEHIND or DIVERGED.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

out=$(git submodule foreach --quiet '
  branch=$(git config -f "$toplevel/.gitmodules" "submodule.$name.branch" 2>/dev/null)
  [ -z "$branch" ] && branch=$(git remote show origin 2>/dev/null | sed -n "s/.*HEAD branch: //p")
  [ -z "$branch" ] && branch=main
  git fetch --quiet origin "$branch" 2>/dev/null || { echo "WARN     $sm_path: fetch of $branch failed"; exit 0; }
  pinned=$(git rev-parse HEAD)
  tip=$(git rev-parse "origin/$branch" 2>/dev/null) || { echo "WARN     $sm_path: no origin/$branch"; exit 0; }
  if [ "$pinned" = "$tip" ]; then
    echo "OK       $sm_path: at tip of $branch"
  elif git merge-base --is-ancestor "$pinned" "$tip"; then
    echo "BEHIND   $sm_path: behind origin/$branch (checkout $branch && pull to fast-forward)"
  else
    echo "DIVERGED $sm_path: pinned commit not in origin/$branch history (unmerged work, OR a squash/rebase-merged PR — the merge rewrote the SHA; verify the PR is merged, then move the pointer to origin/$branch tip)"
  fi
  exit 0
')

echo "$out"
echo "$out" | grep -qE '^(BEHIND|DIVERGED)' && exit 1
exit 0
