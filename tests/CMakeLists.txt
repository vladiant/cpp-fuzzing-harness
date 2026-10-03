cmake_minimum_required(VERSION 3.24)

# Decoder unit tests (design §4.5 / §7.4).
#
# Dependency resolution for GoogleTest:
#   * If a Conan-generated / system GTest package is discoverable, use it.
#   * Otherwise fall back to FetchContent so a bare `cmake` invocation needs no
#     Conan profile setup (BUILD_DECODER_TESTS defaults ON — design handoff).
#
# The test binary links ONLY the sanitized header-only decoder (fuzz_common) and
# GTest — no fuzzer driver — so it runs as an ordinary CTest test.

find_package(GTest CONFIG QUIET)

if(NOT GTest_FOUND)
  include(FetchContent)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.15.0
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
endif()

add_executable(test_operand_decoder test_operand_decoder.cpp)
target_link_libraries(test_operand_decoder PRIVATE fuzz_common GTest::gtest_main)

# Match the harness sanitizer configuration so the decoder is exercised under the
# same instrumentation (minus the libFuzzer coverage/driver, which is not wanted
# for a plain CTest binary).
if(ENABLE_ASAN)
  target_compile_options(test_operand_decoder PRIVATE -fsanitize=address -fno-omit-frame-pointer)
  target_link_options(test_operand_decoder    PRIVATE -fsanitize=address)
endif()
if(ENABLE_UBSAN)
  target_compile_options(test_operand_decoder PRIVATE
      -fsanitize=undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer)
  target_link_options(test_operand_decoder    PRIVATE -fsanitize=undefined)
endif()
target_compile_options(test_operand_decoder PRIVATE -g -O1)

include(GoogleTest)
gtest_discover_tests(test_operand_decoder)
