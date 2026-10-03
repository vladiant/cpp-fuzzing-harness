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

# Sensible CI-friendly defaults; override by passing your own flags.
exec "${BUILD}/${TARGET}" \
     "${ROOT}/corpus/${TARGET}" \
     "${DICT_ARGS[@]}" \
     -max_total_time=30 -max_len=16 -print_final_stats=1 "$@"
