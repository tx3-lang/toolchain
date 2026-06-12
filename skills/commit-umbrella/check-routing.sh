#!/usr/bin/env bash
# Check 3 — every submodule path in .gitmodules is documented in the right AGENTS.md.
# A submodule under <group>/… must appear in <group>/AGENTS.md; paths with no grouping
# AGENTS.md (registry/, docs/) must appear in the root AGENTS.md. Matches either the
# full path (core/tii) or, as a fallback, the basename within the grouping doc, since
# some groupings (e.g. sdks/) route by relative name (rust-sdk/). Run from the umbrella
# repo root. Exits non-zero if any path is undocumented.
#
# Reverse direction (stale routing lines for removed submodules) is left as a manual
# skim — see SKILL.md — because grouping docs legitimately mention non-submodule
# subdirectories (e.g. sdks/scripts, sdks/sdk-spec) that a heuristic would false-flag.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0

while read -r p; do
  group=${p%%/*}
  base=${p##*/}
  doc="$group/AGENTS.md"
  [ -f "$doc" ] || doc="AGENTS.md"
  if grep -q "$p" "$doc" || { [ "$doc" != "AGENTS.md" ] && grep -qE "(^|[^/])$base/" "$doc"; }; then
    echo "OK   $p documented in $doc"
  else
    echo "FAIL $p missing from $doc"
    fail=1
  fi
done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

exit $fail
