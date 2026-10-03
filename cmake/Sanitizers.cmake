# Sanitizers.cmake
#
# Single source of truth for sanitizer + coverage instrumentation.
# `target_fuzzing_instrumentation(<tgt>)` applies identical flag fragments to the
# instrumented upstream library and to every harness so coverage/sanitizer
# instrumentation is consistent across the boundary (no "lib instrumented,
# harness not" gaps).
#
# Design: docs/design/design.md §4.3 / §6.1. Controlled by the ENABLE_ASAN /
# ENABLE_UBSAN / ENABLE_MSAN cache options and FUZZING_ENGINE (set in the root
# CMakeLists.txt before this module is included).

function(target_fuzzing_instrumentation tgt)
  # Coverage feedback:
  #   libFuzzer: -fsanitize=fuzzer-no-link on all non-driver TUs.
  #   AFL++:     afl-clang-fast++ injects coverage automatically (no extra flag).
  if(FUZZING_ENGINE STREQUAL "libfuzzer")
    target_compile_options(${tgt} PRIVATE -fsanitize=fuzzer-no-link)
  endif()

  if(ENABLE_ASAN)
    target_compile_options(${tgt} PRIVATE -fsanitize=address -fno-omit-frame-pointer)
    target_link_options(${tgt}    PRIVATE -fsanitize=address)
  endif()

  if(ENABLE_UBSAN)
    target_compile_options(${tgt} PRIVATE
        -fsanitize=undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer)
    target_link_options(${tgt}    PRIVATE -fsanitize=undefined)
  endif()

  if(ENABLE_MSAN)
    target_compile_options(${tgt} PRIVATE
        -fsanitize=memory -fsanitize-memory-track-origins=2 -fno-omit-frame-pointer)
    target_link_options(${tgt}    PRIVATE -fsanitize=memory)
  endif()

  # Debug info + light optimization for good, stable stack traces.
  target_compile_options(${tgt} PRIVATE -g -O1)
endfunction()
