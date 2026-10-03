#!/usr/bin/env bash
# ci_regression_gate.sh — deterministic, NON-mutating regression gate.
#
# Replays the curated reproducers under corpus/regression/<target>/ with
# `-runs=0` (no fuzzing, no new units written). For a UB target the replay MUST
# reproduce the catalogued UBSan finding (non-zero exit == PASS). If it ever
# exits 0 the UB stopped firing and the regression gate turns RED — the true
# regression signal (SRS FR-17/FR-18, design §5.3/§7.3).
#
# Usage: scripts/ci_regression_gate.sh <target>
# Used by .github/workflows/fuzz-libfuzzer.yml.
set -euo pipefail

TARGET="${1:?usage: ci_regression_gate.sh <target>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${BUILD_DIR:-${ROOT}/build-libfuzzer}"
EXE="${BUILD}/${TARGET}"
SEEDS="${ROOT}/corpus/regression/${TARGET}"

[[ -x "${EXE}" ]]   || { echo "::error::missing binary ${EXE} — build the preset first"; exit 2; }
[[ -d "${SEEDS}" ]] || { echo "::error::no regression seeds at ${SEEDS}"; exit 2; }

export UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1:abort_on_error=1"
export ASAN_OPTIONS="abort_on_error=1:halt_on_error=1"

echo "=== ${TARGET}: deterministic regression replay (-runs=0) ==="
set +e
"${EXE}" "${SEEDS}" -runs=0
RC=$?
set -e

if [[ "${RC}" -ne 0 ]]; then
  echo "PASS: ${TARGET} regression seeds still reproduce the UB (rc=${RC})"; exit 0
fi
echo "::error::${TARGET} regression seeds no longer reproduce (rc=0) — UB regression gate RED"; exit 1
