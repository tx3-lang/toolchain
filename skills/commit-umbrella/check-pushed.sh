#!/usr/bin/env bash
# Check 1 — every submodule's pinned commit is reachable on its remote.
# Run from the umbrella repo root. Exits non-zero if any submodule has unpushed
# commits, a merge conflict, or a dirty working tree.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

out=$(git submodule foreach --quiet '
  prefix=$(git -C "$toplevel" submodule status -- "$sm_path" | cut -c1)
  if [ "$prefix" = "U" ]; then echo "FAIL  $sm_path: merge conflict"; exit 0; fi
  sha=$(git rev-parse HEAD)
  git fetch --quiet origin || echo "WARN  $sm_path: fetch failed (push check unreliable)"
  if git branch -r --contains "$sha" | grep -q .; then
    echo "OK    $sm_path: $sha is on remote"
  else
    echo "FAIL  $sm_path: $sha NOT pushed (no remote branch contains it)"
  fi
  [ -n "$(git status --porcelain)" ] && echo "DIRTY $sm_path: uncommitted changes — pinned pointer is provisional"
  exit 0
')

echo "$out"
echo "$out" | grep -qE '^(FAIL|DIRTY)' && exit 1
exit 0
