#!/usr/bin/env bash
# ci_libfuzzer_gate.sh — run ONE libFuzzer target under a short, CI-friendly
# budget inside a throwaway SCRATCH dir and gate on the expected outcome.
#
# Usage: scripts/ci_libfuzzer_gate.sh <target> <crash|clean> [budget_seconds]
#   crash  -> the target MUST crash within the budget (UBSan UB targets). Non-zero
#             exit == PASS; a clean exit (rc=0) == FAIL (the UB stopped firing).
#   clean  -> the target MUST stay clean (checked/clamped). rc=0 == PASS; any
#             non-zero exit (a sanitizer finding) == FAIL.
#
# The tracked corpus/ is NEVER used as the writable dir: a scratch copy of the
# seeds is handed to libFuzzer and -artifact_prefix points into the scratch dir,
# so neither CI nor a local run can mutate corpus/ or drop crash-* blobs in the
# tree (defect D-2). Used by .github/workflows/fuzz-libfuzzer.yml.
set -euo pipefail

TARGET="${1:?usage: ci_libfuzzer_gate.sh <target> <crash|clean> [budget]}"
EXPECT="${2:?expected outcome: crash|clean}"
BUDGET="${3:-45}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${BUILD_DIR:-${ROOT}/build-libfuzzer}"
EXE="${BUILD}/${TARGET}"
[[ -x "${EXE}" ]] || { echo "::error::missing binary ${EXE} — build the preset first"; exit 2; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT
WORK="${SCRATCH}/corpus"
mkdir -p "${WORK}"
# Seed the writable scratch corpus from the tracked, read-only seeds.
[[ -d "${ROOT}/corpus/${TARGET}" ]] && cp -r "${ROOT}/corpus/${TARGET}/." "${WORK}/" 2>/dev/null || true

# Reproducible, abort-on-first-finding runtime options (design §6.2).
export UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1:abort_on_error=1"
export ASAN_OPTIONS="abort_on_error=1:halt_on_error=1:detect_leaks=1:allocator_may_return_null=0"

DICT="${ROOT}/dictionaries/int16_boundaries.dict"
DICT_ARG=()
[[ -f "${DICT}" ]] && DICT_ARG=("-dict=${DICT}")

echo "=== ${TARGET}: libFuzzer short run (expect=${EXPECT}, budget=${BUDGET}s) ==="
set +e
"${EXE}" "${WORK}" "${DICT_ARG[@]}" \
    -max_total_time="${BUDGET}" -max_len=16 \
    -artifact_prefix="${SCRATCH}/${TARGET}-" -print_final_stats=1
RC=$?
set -e

case "${EXPECT}" in
  crash)
    if [[ "${RC}" -ne 0 ]]; then
      echo "PASS: ${TARGET} crashed as expected (rc=${RC})"; exit 0
    fi
    echo "::error::${TARGET} did NOT crash within ${BUDGET}s (rc=0) — expected UB to fire"; exit 1 ;;
  clean)
    if [[ "${RC}" -eq 0 ]]; then
      echo "PASS: ${TARGET} stayed clean (rc=0)"; exit 0
    fi
    echo "::error::${TARGET} crashed (rc=${RC}) but was expected to stay clean"; exit 1 ;;
  *)
    echo "::error::unknown expectation '${EXPECT}' (use crash|clean)"; exit 2 ;;
esac
