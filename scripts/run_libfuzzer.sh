#!/usr/bin/env bash
# run_libfuzzer.sh — configure + build + time-box one libFuzzer target.
# Usage: scripts/run_libfuzzer.sh <target-name> [extra libFuzzer args...]
#   e.g. scripts/run_libfuzzer.sh simple_calc_divide -max_total_time=30
#
# Design §7.1. Default engine is libFuzzer with ASan+UBSan; no AFL/Conan needed.
set -euo pipefail

TARGET="${1:?usage: run_libfuzzer.sh <target-name> [libfuzzer args...]}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/build-libfuzzer"
CXX="${CXX:-/usr/bin/clang++}"

cmake -S "${ROOT}" -B "${BUILD}" -G Ninja \
      -DCMAKE_CXX_COMPILER="${CXX}" \
      -DFUZZING_ENGINE=libfuzzer -DENABLE_ASAN=ON -DENABLE_UBSAN=ON

cmake --build "${BUILD}" --target "fuzz_${TARGET}_libfuzzer"

DICT_ARGS=()
[[ -f "${ROOT}/dictionaries/int16_boundaries.dict" ]] && \
  DICT_ARGS+=("-dict=${ROOT}/dictionaries/int16_boundaries.dict")

export UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1:abort_on_error=1"
export ASAN_OPTIONS="abort_on_error=1:halt_on_error=1:detect_leaks=1:allocator_may_return_null=0"

# D-2 hygiene: never let libFuzzer write new units or crash blobs into the
# tracked corpus. Use a scratch WORK dir (override with FUZZ_OUTPUT_DIR) seeded
# from the read-only corpus; new units + reproducers land in the scratch dir.
WORK="${FUZZ_OUTPUT_DIR:-$(mktemp -d)}"
mkdir -p "${WORK}/corpus"
[[ -d "${ROOT}/corpus/${TARGET}" ]] && \
  cp -r "${ROOT}/corpus/${TARGET}/." "${WORK}/corpus/" 2>/dev/null || true
echo "libFuzzer scratch output dir: ${WORK}" >&2

# Sensible CI-friendly defaults; override by passing your own flags.
# Writable scratch corpus first (new units go here), tracked seeds read-only next.
exec "${BUILD}/${TARGET}" \
     "${WORK}/corpus" \
     "${ROOT}/corpus/${TARGET}" \
     "${DICT_ARGS[@]}" \
     -artifact_prefix="${WORK}/${TARGET}-" \
     -max_total_time=30 -max_len=16 -print_final_stats=1 "$@"
