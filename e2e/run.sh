#!/usr/bin/env bash
#
# DX end-to-end test runner for the Tx3 toolchain.
#
# Drives the real toolchain binaries through a developer's journey and reports
# pass/fail per journey. It validates the *assembled* experience — that trix,
# tx3c, dolos and cshell interoperate — which no single submodule's tests cover.
#
# Binary-source modes (which binaries the journeys exercise):
#   --channel <stable|beta|nightly>   install that channel via tx3up, then test
#                                      it (black-box test of what actually ships)
#   --local                            use locally-built binaries: trix from PATH
#                                      or $TX3_TRIX_PATH, and the helpers via
#                                      $TX3_{TX3C,DOLOS,CSHELL}_PATH (or PATH).
#                                      Validates unreleased changes; never touches
#                                      ~/.tx3.
#   (default)                          use whatever `trix` is already on PATH.
#
# See e2e/README.md for details.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB="${SCRIPT_DIR}/lib/common.sh"
JOURNEY_DIR="${SCRIPT_DIR}/journeys"

# --- defaults --------------------------------------------------------------

MODE="path"            # path | channel | local
CHANNEL=""
ONLY_JOURNEY=""
ISOLATE="auto"         # auto | yes | no (channel mode HOME isolation)
VERBOSE="0"
KEEP="0"
ARTIFACTS_DIR=""
LIST_JSON="0"

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --channel <ch>      Install + test a released channel via tx3up
  --local             Test locally-built binaries (TX3_*_PATH / PATH)
  --journey <name>    Run a single journey (directory name under journeys/)
  --list-json         Print journeys + their min-tx3c as JSON and exit (no install)
  --no-isolate        Channel mode: install into the ambient $HOME (CI default)
  --isolate           Channel mode: install into a throwaway $HOME
  --artifacts-dir D   On failure, copy preserved logs/workdirs into D
  --keep              Keep journey workdirs even on success
  --verbose           Stream child command output
  -h, --help          Show this help
EOF
}

# --- arg parsing -----------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel)      MODE="channel"; CHANNEL="${2:-}"; shift 2 ;;
    --local)        MODE="local"; shift ;;
    --journey)      ONLY_JOURNEY="${2:-}"; shift 2 ;;
    --list-json)    LIST_JSON="1"; shift ;;
    --isolate)      ISOLATE="yes"; shift ;;
    --no-isolate)   ISOLATE="no"; shift ;;
    --artifacts-dir) ARTIFACTS_DIR="${2:-}"; shift 2 ;;
    --keep)         KEEP="1"; shift ;;
    --verbose|-v)   VERBOSE="1"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

# shellcheck source=lib/common.sh
source "${LIB}"

[[ "${MODE}" == "channel" && -z "${CHANNEL}" ]] && die "--channel requires a value (stable|beta|nightly)"

# --- journey list (machine-readable) ---------------------------------------

# `--list-json` emits each journey + its declared min-tx3c and exits, without
# touching any binaries — the feed the CI matrix builder consumes.
if [[ "${LIST_JSON}" == "1" ]]; then
  out="["; sep=""
  for d in "${JOURNEY_DIR}"/*/; do
    [[ -f "${d}journey.sh" ]] || continue
    n="$(basename "${d%/}")"
    m="$(journey_min_tx3c "${d}journey.sh")"
    if [[ -n "${m}" ]]; then
      out+="${sep}{\"name\":\"${n}\",\"min_tx3c\":\"${m}\"}"
    else
      out+="${sep}{\"name\":\"${n}\",\"min_tx3c\":null}"
    fi
    sep=","
  done
  printf '%s]\n' "${out}"
  exit 0
fi

# --- run root + cleanup ----------------------------------------------------

# Resolve to the real path (macOS symlinks /var -> /private/var); dolos logs the
# real path, so this keeps the leaked-devnet reap below matching reliably.
RUN_ROOT="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/dx-e2e.XXXXXX")" && pwd -P)"
RUN_ID="$(basename "${RUN_ROOT}")"
ISO_HOME=""            # throwaway HOME, when channel-mode isolation is active
FAILED="0"

cleanup() {
  # The throwaway install is never useful for debugging — always reclaim it.
  [[ -n "${ISO_HOME}" ]] && rm -rf "${ISO_HOME}"
  # Keep the run logs/workdirs for inspection when something failed (or --keep).
  if [[ "${FAILED}" == "1" ]]; then
    warn "preserved run artifacts at: ${RUN_ROOT}"
    if [[ -n "${ARTIFACTS_DIR}" ]]; then
      mkdir -p "${ARTIFACTS_DIR}"
      cp -R "${RUN_ROOT}/." "${ARTIFACTS_DIR}/" 2>/dev/null || true
      warn "copied artifacts to: ${ARTIFACTS_DIR}"
    fi
    return
  fi
  [[ "${KEEP}" == "1" ]] || rm -rf "${RUN_ROOT}"
}
trap cleanup EXIT

# --- binary resolution -----------------------------------------------------

# Default: rely on PATH; modes below may override.
TRIX="${TX3_TRIX_PATH:-trix}"

resolve_helper() {
  # resolve_helper <tool> — ensure trix can find a helper in --local mode by
  # exporting TX3_<TOOL>_PATH. Honors a caller-provided override first.
  local tool="$1"
  local var="TX3_${tool^^}_PATH"
  if [[ -n "${!var:-}" ]]; then
    [[ -x "${!var}" ]] || die "${var}=${!var} is not an executable"
    info "  ${tool}: ${!var} (from ${var})"
    return
  fi
  local found; found="$(command -v "${tool}" 2>/dev/null || true)"
  [[ -n "${found}" ]] || die "could not find '${tool}'; set ${var} or put it on PATH (--local)"
  export "${var}=${found}"
  info "  ${tool}: ${found} (from PATH)"
}

case "${MODE}" in
  channel)
    command -v tx3up >/dev/null 2>&1 || die \
      "tx3up not found — install it first (see e2e/README.md), then re-run with --channel"

    # Isolate by default for local invocations so we never clobber a developer's
    # real ~/.tx3; CI runners are already ephemeral, so they pass --no-isolate.
    if [[ "${ISOLATE}" == "yes" || ( "${ISOLATE}" == "auto" && -z "${CI:-}" ) ]]; then
      ISO_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dx-e2e-home.XXXXXX")"
      export HOME="${ISO_HOME}"
      info "isolating install under HOME=${HOME}"
    fi

    info "installing toolchain channel '${CHANNEL}' via tx3up"
    # NOTE: deliberately NOT running `tx3up use` — that repoints ~/.tx3/default
    # and would mutate the developer's active channel. We resolve the channel's
    # own bin dir explicitly instead, so channel mode is non-destructive by
    # construction (isolated or not). `install` only refreshes <channel>/bin.
    tx3up --channel "${CHANNEL}" install || die "tx3up install failed for channel '${CHANNEL}'"

    # Resolve against the channel's own bin dir, which tx3up definitively
    # populates — robust against the ~/.tx3/default symlink not being set up.
    chan_bin="${HOME}/.tx3/${CHANNEL}/bin"
    [[ -d "${chan_bin}" ]] || die "channel bin dir not found after install: ${chan_bin}"
    for tool in trix tx3c dolos cshell; do
      [[ -x "${chan_bin}/${tool}" ]] || die \
        "channel '${CHANNEL}' install is incomplete — missing '${tool}' at ${chan_bin}"
    done
    # Pin trix's helper resolution to the channel binaries and expose them on PATH.
    export TX3_TX3C_PATH="${chan_bin}/tx3c"
    export TX3_DOLOS_PATH="${chan_bin}/dolos"
    export TX3_CSHELL_PATH="${chan_bin}/cshell"
    export PATH="${chan_bin}:${PATH}"
    TRIX="${chan_bin}/trix"
    ;;

  local)
    TRIX="${TX3_TRIX_PATH:-$(command -v trix 2>/dev/null || true)}"
    [[ -n "${TRIX}" ]] || die "trix not found — set TX3_TRIX_PATH or put trix on PATH (--local)"
    info "trix: ${TRIX}"
    # trix resolves these via TX3_<TOOL>_PATH (see trix home.rs); pin them so a
    # local run never falls back to a ~/.tx3 install.
    resolve_helper tx3c
    resolve_helper dolos
    resolve_helper cshell
    ;;

  path)
    command -v "${TRIX}" >/dev/null 2>&1 || die \
      "trix not found on PATH — install the toolchain, or use --channel / --local"
    ;;
esac

export TRIX

info "toolchain under test:"
"${TRIX}" --version 2>&1 | sed 's/^/    /' || die "'${TRIX} --version' failed — toolchain not usable"

# Resolve a tx3c for the per-journey capability gate (channel-aware skipping).
case "${MODE}" in
  channel) TX3C="${chan_bin}/tx3c" ;;
  local)   TX3C="${TX3_TX3C_PATH:-}" ;;
  path)    TX3C="${TX3_TX3C_PATH:-$(command -v tx3c 2>/dev/null || echo "${HOME}/.tx3/default/bin/tx3c")}" ;;
esac
TX3C_VERSION=""
if [[ -n "${TX3C}" && -x "${TX3C}" ]]; then
  TX3C_VERSION="$("${TX3C}" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
fi
[[ -n "${TX3C_VERSION}" ]] && info "tx3c ${TX3C_VERSION} (capability gate)"

# --- journey discovery -----------------------------------------------------

journeys=()
if [[ -n "${ONLY_JOURNEY}" ]]; then
  [[ -f "${JOURNEY_DIR}/${ONLY_JOURNEY}/journey.sh" ]] \
    || die "no such journey: ${ONLY_JOURNEY} (looked for journeys/${ONLY_JOURNEY}/journey.sh)"
  journeys=("${JOURNEY_DIR}/${ONLY_JOURNEY}")
else
  for d in "${JOURNEY_DIR}"/*/; do
    [[ -f "${d}journey.sh" ]] && journeys+=("${d%/}")
  done
fi
[[ ${#journeys[@]} -gt 0 ]] || die "no journeys found under ${JOURNEY_DIR}"

# --- devnet port preflight -------------------------------------------------

# trix's devnet (Dolos) binds these fixed local ports. A pre-existing listener
# (e.g. a leaked devnet from an earlier run, or `trix devnet` running elsewhere)
# would poison the round-trip, so warn loudly. Best-effort via bash /dev/tcp.
port_busy() { ( exec 3<>"/dev/tcp/127.0.0.1/$1" ) >/dev/null 2>&1; }
for port in 8164 5164; do
  if port_busy "${port}"; then
    warn "port ${port} is already in use — a devnet may be running; the round-trip may be unreliable"
  fi
done

# --- run journeys ----------------------------------------------------------

names=(); results=(); durations=()

for jdir in "${journeys[@]}"; do
  name="$(basename "${jdir}")"

  printf '\n%s──────── %s ────────%s\n' "${_C_DIM}" "${name}" "${_C_RESET}"

  # Capability gate: skip (don't fail) a journey whose declared min-tx3c the
  # channel under test can't satisfy. Fail-open when the tx3c version is unknown.
  min_tx3c="$(journey_min_tx3c "${jdir}/journey.sh")"
  if [[ -n "${min_tx3c}" && -n "${TX3C_VERSION}" ]] && ! version_ge "${TX3C_VERSION}" "${min_tx3c}"; then
    skip "${name} — needs tx3c >= ${min_tx3c}, have ${TX3C_VERSION}"
    names+=("${name}"); results+=("⏭ skip"); durations+=("-")
    continue
  fi

  workdir="${RUN_ROOT}/${name}"
  logfile="${RUN_ROOT}/${name}.log"
  mkdir -p "${workdir}"
  start="${SECONDS}"

  if [[ "${VERBOSE}" == "1" ]]; then
    ( cd "${workdir}" \
        && E2E_LIB="${LIB}" TRIX="${TRIX}" E2E_VERBOSE=1 \
           LAST_OUTPUT_FILE="${workdir}/.last_cmd_output" \
           bash "${jdir}/journey.sh" ) 2>&1 | tee "${logfile}"
    rc="${PIPESTATUS[0]}"
  else
    ( cd "${workdir}" \
        && E2E_LIB="${LIB}" TRIX="${TRIX}" E2E_VERBOSE=0 \
           LAST_OUTPUT_FILE="${workdir}/.last_cmd_output" \
           bash "${jdir}/journey.sh" ) > "${logfile}" 2>&1
    rc=$?
  fi

  dur=$(( SECONDS - start ))
  names+=("${name}"); durations+=("${dur}s")

  # Reap any devnet daemon trix spawned for this journey. trix kills its own
  # dolos on the happy path, but leaks it when `trix test` errors in its expect
  # phase — matching on this run's unique id + journey keeps reruns hermetic
  # without touching a developer's own devnets.
  pkill -f "dolos.*${RUN_ID}/${name}" >/dev/null 2>&1 || true

  if [[ "${rc}" -eq 0 ]]; then
    results+=("✅ pass")
    [[ "${VERBOSE}" == "1" ]] || ok "${name} passed (${dur}s)"
    [[ "${KEEP}" == "1" ]] || rm -rf "${workdir}"
  else
    results+=("❌ fail")
    FAILED="1"
    err "${name} failed (${dur}s) — log: ${logfile}"
    if [[ "${VERBOSE}" != "1" ]]; then
      printf '%s---- %s output ----%s\n' "${_C_DIM}" "${name}" "${_C_RESET}" >&2
      cat "${logfile}" >&2
      printf '%s--------------------%s\n' "${_C_DIM}" "${_C_RESET}" >&2
    fi
  fi
done

# --- summary ---------------------------------------------------------------

echo
echo "| Journey | Result | Duration |"
echo "|---------|--------|----------|"
for i in "${!names[@]}"; do
  printf '| %s | %s | %s |\n' "${names[$i]}" "${results[$i]}" "${durations[$i]}"
done
echo

passed=0; skipped=0; failed=0
for r in "${results[@]}"; do
  case "${r}" in
    *pass*) passed=$((passed + 1)) ;;
    *skip*) skipped=$((skipped + 1)) ;;
    *fail*) failed=$((failed + 1)) ;;
  esac
done

if [[ "${FAILED}" == "1" ]]; then
  err "DX e2e: ${failed} failed, ${passed} passed, ${skipped} skipped."
  exit 1
fi
ok "DX e2e: ${passed} passed, ${skipped} skipped."
