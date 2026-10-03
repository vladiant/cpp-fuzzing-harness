# FuzzingEngine.cmake
#
# Resolves the fuzzing engine driver that supplies `main()` + the feedback loop,
# based on the FUZZING_ENGINE cache variable. Sets the cache/normal variable
# FUZZ_DRIVER_LINK, consumed by cmake/AddFuzzHarness.cmake at link time.
#
# Design: docs/design/design.md §4.4.
#   libfuzzer -> link-time `-fsanitize=fuzzer` (clang's libFuzzer; provides main()).
#   afl       -> link libAFLDriver.a (aflpp_driver provides a compatible main()).
#
# Graceful fallback (NFR-2/C-3): the default FUZZING_ENGINE=libfuzzer path NEVER
# touches AFL discovery, so a clang-18-only box configures and builds with zero
# AFL dependency. AFL discovery is reached only when explicitly requested.

if(FUZZING_ENGINE STREQUAL "libfuzzer")
  set(FUZZ_DRIVER_LINK "-fsanitize=fuzzer")

elseif(FUZZING_ENGINE STREQUAL "afl")
  # AFL++ requires a different compiler (afl-clang-fast++ / afl-clang-lto++).
  if(NOT CMAKE_CXX_COMPILER MATCHES "afl-clang")
    message(FATAL_ERROR
      "FUZZING_ENGINE=afl requires an AFL++ compiler. Re-configure with "
      "-DCMAKE_CXX_COMPILER=afl-clang-fast++ (or afl-clang-lto++).")
  endif()

  # aflpp_driver supplies an LLVMFuzzerTestOneInput-compatible main().
  if(NOT AFL_DRIVER_PATH)
    find_library(AFL_DRIVER_PATH
      NAMES AFLDriver libAFLDriver AFLppDriver
      PATHS /usr/lib/aflplusplus /usr/local/lib/aflplusplus
            /usr/lib/afl /usr/local/lib ENV AFL_PATH)
  endif()

  # Some AFL++ packagings ship only the driver object file. Wrap it in a tiny
  # static library so it links like a normal archive (design R-3).
  if(NOT AFL_DRIVER_PATH)
    find_file(AFL_DRIVER_OBJECT
      NAMES aflpp_driver.o
      PATHS /usr/lib/aflplusplus /usr/local/lib/aflplusplus
            /usr/lib/afl /usr/local/lib ENV AFL_PATH)
    if(AFL_DRIVER_OBJECT)
      add_library(aflpp_driver STATIC IMPORTED GLOBAL)
      set_target_properties(aflpp_driver PROPERTIES
        IMPORTED_LOCATION "${AFL_DRIVER_OBJECT}")
      set(AFL_DRIVER_PATH aflpp_driver)
    endif()
  endif()

  if(NOT AFL_DRIVER_PATH)
    message(FATAL_ERROR
      "AFL++ driver (libAFLDriver.a / aflpp_driver.o) not found. "
      "Install afl++ or set -DAFL_DRIVER_PATH=/path/to/libAFLDriver.a")
  endif()

  set(FUZZ_DRIVER_LINK ${AFL_DRIVER_PATH})

else()
  message(FATAL_ERROR
    "Unknown FUZZING_ENGINE='${FUZZING_ENGINE}'. Use 'libfuzzer' or 'afl'.")
endif()
