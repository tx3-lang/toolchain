#!/usr/bin/env bash
# Grouping-contract step 5 — confirm a crate version is live on the crates.io sparse index.
# Encodes the official sparse-index path layout once so skills never hand-write it: names of
# 1/2/3 chars use 1/, 2/, 3/<c1>/ prefixes, 4+ chars use <c1c2>/<c3c4>/ (e.g. tx3-tir ->
# tx/3-/tx3-tir, serde -> se/rd/serde). Hand-writing this per crate is the fiddly, error-prone
# step every grouping skill's verify repeats — and a wrong path silently reads as "not published".
# Usage: crate-published.sh <crate> <version>
# Prints PUBLISHED + exit 0 when the exact version is in the index; MISSING + exit 1 otherwise.
set -uo pipefail
crate=${1:?usage: crate-published.sh <crate> <version>}
version=${2:?usage: crate-published.sh <crate> <version>}

lc=$(printf '%s' "$crate" | tr '[:upper:]' '[:lower:]')
n=${#lc}
case "$n" in
  1) path="1/$lc" ;;
  2) path="2/$lc" ;;
  3) path="3/${lc:0:1}/$lc" ;;
  *) path="${lc:0:2}/${lc:2:2}/$lc" ;;
esac
url="https://index.crates.io/$path"

body=$(curl -fsSL "$url" 2>/dev/null) || { echo "MISSING   $crate $version — index path $path not found (crate never published?)"; exit 1; }
# Each line is one version's JSON record: {"name":...,"vers":"<version>",...}. Match with a
# here-string, not a pipe: under `pipefail`, `grep -q` exits on first match and the SIGPIPE it
# sends upstream would mark the pipeline failed for large indexes (false MISSING).
if grep -q "\"vers\":\"$version\"" <<<"$body"; then
  echo "PUBLISHED $crate $version (index.crates.io/$path)"
  exit 0
fi
echo "MISSING   $crate $version not yet in index.crates.io/$path (latest: $(grep -o '"vers":"[^"]*"' <<<"$body" | tail -n1))"
exit 1
