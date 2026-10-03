#!/usr/bin/env bash
# run_afl.sh — configure + build + time-box one AFL++ target (CI only).
# Usage: scripts/run_afl.sh <target-name> [-V seconds]
#   e.g. scripts/run_afl.sh basic_operation -V 60
#
# Requires afl++ (afl-clang-fast++ + libAFLDriver.a). Design §7.2.
set -euo pipefail

TARGET="${1:?usage: run_afl.sh <target-name> [afl-fuzz args...]}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/build-afl"
CXX="${AFL_CXX:-afl-clang-fast++}"

cmake -S "${ROOT}" -B "${BUILD}" -G Ninja \
      -DCMAKE_CXX_COMPILER="${CXX}" \
      -DFUZZING_ENGINE=afl -DENABLE_ASAN=ON -DENABLE_UBSAN=ON \
      -DBUILD_DECODER_TESTS=OFF

cmake --build "${BUILD}" --target "fuzz_${TARGET}_afl"

export AFL_SKIP_CPUFREQ=1
export UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1:abort_on_error=1"
export ASAN_OPTIONS="abort_on_error=1:halt_on_error=1"

DICT_ARGS=()
[[ -f "${ROOT}/dictionaries/int16_boundaries.dict" ]] && \
  DICT_ARGS+=("-x" "${ROOT}/dictionaries/int16_boundaries.dict")

# D-2 hygiene: AFL++ reads the seed corpus (-i) read-only, so the tracked corpus
# is never mutated; only the findings dir is written. Default it to findings-*/
# (gitignored); override with FUZZ_OUTPUT_DIR (e.g. a CI scratch dir).
OUTDIR="${FUZZ_OUTPUT_DIR:-${ROOT}/findings-${TARGET}}"
mkdir -p "${OUTDIR}"
echo "AFL++ findings dir: ${OUTDIR}" >&2

exec afl-fuzz -i "${ROOT}/corpus/${TARGET}" -o "${OUTDIR}" \
     "${DICT_ARGS[@]}" "${@:--V 60}" \
     -- "${BUILD}/${TARGET}"
