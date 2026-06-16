#!/usr/bin/env bash
#
# Emit the GitHub Actions matrix for the DX e2e workflow: every
# {os, channel, journey} combination whose channel's tx3c floor satisfies the
# journey's declared `#@ min-tx3c`. Incompatible combinations are filtered out
# so no doomed job is ever scheduled.
#
# Journey metadata is read via e2e/lib/common.sh (the same parser the runner
# uses); each channel's tx3c floor is the base version of the `tx3c` VersionReq
# in manifest-<channel>.json.
#
# Usage: scripts/dx-e2e-matrix.sh "<os1> <os2> …" "<channel1> <channel2> …"
# Output: {"include":[{"os":…,"channel":…,"journey":…}, …]}  (single line)

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../e2e/lib/common.sh
source "${REPO_ROOT}/e2e/lib/common.sh"   # journey_min_tx3c, version_ge

OSES="${1:?usage: dx-e2e-matrix.sh \"<os…>\" \"<channel…>\"}"
CHANNELS="${2:?usage: dx-e2e-matrix.sh \"<os…>\" \"<channel…>\"}"

# channel_tx3c_floor <channel> — base version of tx3c's VersionReq in the
# channel manifest (e.g. "^0.22.0" -> "0.22.0"); empty if not found.
channel_tx3c_floor() {
  local mf="${REPO_ROOT}/manifest-${1}.json"
  [[ -f "${mf}" ]] || return 0
  python3 - "${mf}" <<'PY' 2>/dev/null
import json, re, sys
tools = json.load(open(sys.argv[1])).get("tools", [])
v = next((t.get("version", "") for t in tools if t.get("name") == "tx3c"), "")
m = re.search(r"\d+\.\d+\.\d+", v)
print(m.group(0) if m else "")
PY
}

entries=()
for ch in ${CHANNELS}; do
  floor="$(channel_tx3c_floor "${ch}")"
  for d in "${REPO_ROOT}"/e2e/journeys/*/; do
    [[ -f "${d}journey.sh" ]] || continue
    jname="$(basename "${d%/}")"
    jmin="$(journey_min_tx3c "${d}journey.sh")"
    # Skip combos whose channel floor is below the journey's min (fail-open when
    # either is unknown — version_ge returns true and the runner re-checks live).
    if [[ -n "${jmin}" ]] && ! version_ge "${floor}" "${jmin}"; then
      continue
    fi
    for os in ${OSES}; do
      entries+=("{\"os\":\"${os}\",\"channel\":\"${ch}\",\"journey\":\"${jname}\"}")
    done
  done
done

printf '{"include":['
for i in "${!entries[@]}"; do
  [[ "${i}" -gt 0 ]] && printf ','
  printf '%s' "${entries[$i]}"
done
printf ']}\n'
