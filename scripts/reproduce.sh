#!/usr/bin/env bash
# reproduce.sh — deterministically replay a persisted crash on a libFuzzer binary.
# Usage: scripts/reproduce.sh <target-name> <crash-file>
#   e.g. scripts/reproduce.sh simple_calc_divide crash-abc123
#
# Design §7.3 / FR-17. Single-file replay (no mutation) reproduces the finding
# with full sanitizer context.
set -euo pipefail

TARGET="${1:?usage: reproduce.sh <target-name> <crash-file>}"
CRASH="${2:?usage: reproduce.sh <target-name> <crash-file>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/build-libfuzzer"
EXE="${BUILD}/${TARGET}"

[[ -x "${EXE}" ]] || { echo "Build ${TARGET} first (scripts/run_libfuzzer.sh)"; exit 1; }
[[ -f "${CRASH}" ]] || { echo "Crash file not found: ${CRASH}"; exit 1; }

export UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1:abort_on_error=1"
export ASAN_OPTIONS="abort_on_error=1:halt_on_error=1"

exec "${EXE}" "${CRASH}"
