# AddFuzzHarness.cmake
#
# add_fuzz_harness(NAME <name> SOURCE <path/to/<name>_fuzzer.cpp>)
#
# Creates one fuzz-target executable `fuzz_<name>_<engine>` with the output name
# `<name>`, linked against the instrumented SampleLib, the header-only decoder,
# and the active engine driver. All engine/sanitizer wiring is inherited from the
# helper functions so adding a target is a one-liner (NFR-8).
#
# Design: docs/design/design.md §4.5 / §4.6.

function(add_fuzz_harness)
  cmake_parse_arguments(FH "" "NAME;SOURCE" "" ${ARGN})

  if(NOT FH_NAME)
    message(FATAL_ERROR "add_fuzz_harness: NAME is required")
  endif()
  if(NOT FH_SOURCE)
    message(FATAL_ERROR "add_fuzz_harness: SOURCE is required")
  endif()

  set(tgt "fuzz_${FH_NAME}_${FUZZING_ENGINE}") # e.g. fuzz_simple_calc_divide_libfuzzer

  add_executable(${tgt} ${FH_SOURCE})
  target_link_libraries(${tgt} PRIVATE fuzz::samplelib fuzz_common)
  target_include_directories(${tgt} PRIVATE "${CMAKE_SOURCE_DIR}/fuzz")
  target_fuzzing_instrumentation(${tgt})
  target_link_options(${tgt} PRIVATE ${FUZZ_DRIVER_LINK})
  set_target_properties(${tgt} PROPERTIES OUTPUT_NAME "${FH_NAME}")
endfunction()
