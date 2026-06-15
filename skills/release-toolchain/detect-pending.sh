#!/usr/bin/env bash
# release-toolchain step 0 — detect which submodules have pending releasable work.
# Type-aware, mechanical scan across every submodule, printed as one line each so the
# orchestrator reads a map instead of re-deriving tag/pointer diffs across ~30 repos by hand.
# Companion to commit-umbrella's check-*.sh; run from the umbrella repo root.
#
# Classification (deterministic, with only the genuinely-external policy hardcoded):
#   ADOPT-ONLY  — third-party / deploy-only; never a publish gate (hardcoded denylist).
#   VERIFY-ONLY — protocols/*; release-equivalent is verification, never a publish.
#   release     — has v* tags: PENDING when origin/main is ahead of the latest tag.
#   pointer     — no tags: PENDING when origin/main is ahead of the umbrella-pinned commit.
#
# Output prefixes: PENDING (has work), CURRENT (none), ADOPT-ONLY / VERIFY-ONLY (no publish),
#   WARN (fetch/ref problem — treat as unknown, check by hand). Exit 0 always: this is a
#   report, not a gate (unlike the commit-umbrella checks). The "pins lagging the about-to-
#   publish upstreams" refinement stays in the skill — it needs runtime upstream_versions.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# Third-party / deploy-only submodules we never publish (external policy, not derivable).
DENYLIST="tooling/cshell backends/dolos backends/tx3-hydra backends/protocol-gateway"

git submodule foreach --quiet '
  case " '"$DENYLIST"' " in
    *" $sm_path "*) echo "ADOPT-ONLY  $sm_path: third-party / deploy-only (no publish detection)"; exit 0 ;;
  esac
  case "$sm_path" in
    protocols/*) echo "VERIFY-ONLY $sm_path: verify .tx3 fixtures, never a publish"; exit 0 ;;
  esac

  branch=$(git config -f "$toplevel/.gitmodules" "submodule.$name.branch" 2>/dev/null)
  [ -z "$branch" ] && branch=$(git remote show origin 2>/dev/null | sed -n "s/.*HEAD branch: //p")
  [ -z "$branch" ] && branch=main
  git fetch --quiet --tags origin "$branch" 2>/dev/null || { echo "WARN        $sm_path: fetch of $branch failed"; exit 0; }
  tip=$(git rev-parse "origin/$branch" 2>/dev/null) || { echo "WARN        $sm_path: no origin/$branch"; exit 0; }

  # Latest v* release tag by version order (plugins/actions also carries a moving vN major
  # alias; either way the highest version tag is a valid "last release" baseline).
  tag=$(git tag -l "v*" --sort=-v:refname | head -n1)
  if [ -n "$tag" ]; then
    ahead=$(git rev-list --count "$tag..$tip")
    if [ "$ahead" -gt 0 ]; then
      echo "PENDING     $sm_path: release — $ahead commit(s) on $branch since $tag"
    else
      echo "CURRENT     $sm_path: release — $branch at $tag"
    fi
  else
    pinned=$(git rev-parse HEAD)
    if [ "$pinned" = "$tip" ]; then
      echo "CURRENT     $sm_path: pointer — umbrella pin at tip of $branch"
    elif git merge-base --is-ancestor "$pinned" "$tip"; then
      ahead=$(git rev-list --count "$pinned..$tip")
      echo "PENDING     $sm_path: pointer — $branch advanced $ahead commit(s) past umbrella pin"
    else
      echo "WARN        $sm_path: pointer — pinned commit not in origin/$branch (diverged; check by hand)"
    fi
  fi
'
