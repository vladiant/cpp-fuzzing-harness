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
  #
  # AFL_DRIVER_PATH is the *user-facing override only* (declared as an empty
  # STRING cache entry in the root CMakeLists). It must NOT be reused as the
  # find_library/find_file result variable: find_library is a no-op whenever its
  # result variable is already a set (non-NOTFOUND) cache entry, so writing the
  # search result back into the empty-but-set AFL_DRIVER_PATH silently skips the
  # whole search and discovery can never succeed. Resolve into distinct internal
  # variables instead.
  if(AFL_DRIVER_PATH)
    # Explicit developer override wins (e.g. -DAFL_DRIVER_PATH=/path/libAFLDriver.a).
    set(_afl_driver "${AFL_DRIVER_PATH}")
  else()
    find_library(AFL_DRIVER_LIB
      NAMES AFLDriver libAFLDriver AFLppDriver
      PATHS /usr/lib/aflplusplus /usr/local/lib/aflplusplus
            /usr/lib/afl /usr/local/lib ENV AFL_PATH)
    if(AFL_DRIVER_LIB)
      set(_afl_driver "${AFL_DRIVER_LIB}")
    else()
      # Some AFL++ packagings ship only the driver object file. Wrap it in a tiny
      # static library so it links like a normal archive (design R-3).
      find_file(AFL_DRIVER_OBJECT
        NAMES aflpp_driver.o
        PATHS /usr/lib/aflplusplus /usr/local/lib/aflplusplus
              /usr/lib/afl /usr/local/lib ENV AFL_PATH)
      if(AFL_DRIVER_OBJECT)
        add_library(aflpp_driver STATIC IMPORTED GLOBAL)
        set_target_properties(aflpp_driver PROPERTIES
          IMPORTED_LOCATION "${AFL_DRIVER_OBJECT}")
        set(_afl_driver aflpp_driver)
      endif()
    endif()
  endif()

  if(NOT _afl_driver)
    message(FATAL_ERROR
      "AFL++ driver (libAFLDriver.a / aflpp_driver.o) not found. "
      "Install afl++ or set -DAFL_DRIVER_PATH=/path/to/libAFLDriver.a")
  endif()

  set(FUZZ_DRIVER_LINK ${_afl_driver})

else()
  message(FATAL_ERROR
    "Unknown FUZZING_ENGINE='${FUZZING_ENGINE}'. Use 'libfuzzer' or 'afl'.")
endif()
