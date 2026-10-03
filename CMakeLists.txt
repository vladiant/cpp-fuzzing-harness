cmake_minimum_required(VERSION 3.24)

project(cpp_fuzzing_harness
  VERSION 0.1.0
  DESCRIPTION "Dual-engine (libFuzzer + AFL++) fuzz harnesses for vva::SampleLib"
  LANGUAGES CXX)

# ---------------------------------------------------------------------------
# Build-level options (design §4.1)
# ---------------------------------------------------------------------------
set(FUZZING_ENGINE "libfuzzer" CACHE STRING "Fuzzing engine: libfuzzer | afl")
set_property(CACHE FUZZING_ENGINE PROPERTY STRINGS libfuzzer afl)

option(ENABLE_ASAN  "Enable AddressSanitizer"                         ON)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer"               ON)
option(ENABLE_MSAN  "Enable MemorySanitizer (exclusive with ASan)"    OFF)
option(BUILD_DECODER_TESTS "Build the decoder GoogleTest unit tests"  ON)

set(AFL_DRIVER_PATH "" CACHE STRING "Override path to libAFLDriver.a (AFL engine)")

# ---------------------------------------------------------------------------
# Guard rails (design §4.1 / C-4)
# ---------------------------------------------------------------------------
if(ENABLE_MSAN AND ENABLE_ASAN)
  message(FATAL_ERROR
    "ENABLE_MSAN and ENABLE_ASAN are mutually exclusive. "
    "Configure MSan with -DENABLE_ASAN=OFF -DENABLE_MSAN=ON.")
endif()

if(NOT FUZZING_ENGINE STREQUAL "libfuzzer" AND NOT FUZZING_ENGINE STREQUAL "afl")
  message(FATAL_ERROR
    "FUZZING_ENGINE must be 'libfuzzer' or 'afl' (got '${FUZZING_ENGINE}').")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# Order matters: Sanitizers defines target_fuzzing_instrumentation(), used by
# FetchUpstream (to instrument the lib) and AddFuzzHarness (to instrument exes).
include(Sanitizers)
include(FuzzingEngine)
include(FetchUpstream)
include(AddFuzzHarness)

# ---------------------------------------------------------------------------
# Shared harness infrastructure — header-only decoder + prelude (design §4.6)
# ---------------------------------------------------------------------------
add_library(fuzz_common INTERFACE)
target_include_directories(fuzz_common INTERFACE "${CMAKE_SOURCE_DIR}/fuzz/common")
target_compile_features(fuzz_common INTERFACE cxx_std_17)

# ---------------------------------------------------------------------------
# Fuzz targets (design §4.5). One line per harness (NFR-8).
# ---------------------------------------------------------------------------
add_fuzz_harness(NAME simple_calc_divide  SOURCE fuzz/simple_calc_divide_fuzzer.cpp)
add_fuzz_harness(NAME simple_calc_arith   SOURCE fuzz/simple_calc_arith_fuzzer.cpp)
add_fuzz_harness(NAME basic_operation     SOURCE fuzz/basic_operation_fuzzer.cpp)
add_fuzz_harness(NAME checked_operation   SOURCE fuzz/checked_operation_fuzzer.cpp)
add_fuzz_harness(NAME clamped_operation   SOURCE fuzz/clamped_operation_fuzzer.cpp)
add_fuzz_harness(NAME operation_strategy  SOURCE fuzz/operation_strategy_fuzzer.cpp)

# ---------------------------------------------------------------------------
# Decoder unit tests (design §4.5 / §7.4). libFuzzer tree only, never under MSan
# (keeps the test target free of toolchain friction).
# ---------------------------------------------------------------------------
if(BUILD_DECODER_TESTS AND FUZZING_ENGINE STREQUAL "libfuzzer" AND NOT ENABLE_MSAN)
  enable_testing()
  add_subdirectory(tests)
endif()
