# FetchUpstream.cmake
#
# Populates the upstream `test_cpp_ci` SampleLib at the pinned commit and builds
# an *instrumented* static library (`samplelib_fuzz`) from its sources using THIS
# project's sanitizer/coverage flags (see cmake/Sanitizers.cmake).
#
# Design: docs/design/design.md §4.2 — Populate-only (NOT MakeAvailable) so we do
# not inherit upstream's app/test/coverage/valgrind targets, and we compile the
# code under test with our own instrumentation.

include(FetchContent)

FetchContent_Declare(
  test_cpp_ci
  GIT_REPOSITORY https://github.com/vladiant/test_cpp_ci.git
  GIT_TAG        2154ed741002263b493eb15fd8c1a419117adfa5 # pinned (FR-19/20)
)

# POPULATE ONLY — do NOT MakeAvailable (that would add upstream's app/test/
# coverage/valgrind targets). We want the sources, not the build.
FetchContent_GetProperties(test_cpp_ci)
if(NOT test_cpp_ci_POPULATED)
  FetchContent_Populate(test_cpp_ci)
endif()

# Define the instrumented library from exactly the fetched sources.
file(GLOB SAMPLELIB_SOURCES CONFIGURE_DEPENDS
     "${test_cpp_ci_SOURCE_DIR}/lib/src/*.cpp")

if(NOT SAMPLELIB_SOURCES)
  message(FATAL_ERROR
    "No upstream sources found under ${test_cpp_ci_SOURCE_DIR}/lib/src. "
    "Has the upstream layout changed for the pinned commit?")
endif()

add_library(samplelib_fuzz STATIC ${SAMPLELIB_SOURCES})
target_include_directories(samplelib_fuzz PUBLIC
     "${test_cpp_ci_SOURCE_DIR}/lib/include")
target_compile_features(samplelib_fuzz PUBLIC cxx_std_17)

# Apply the SAME sanitizer/coverage instrumentation used on the harnesses so the
# instrumentation boundary is seamless (defined in cmake/Sanitizers.cmake).
target_fuzzing_instrumentation(samplelib_fuzz)

add_library(fuzz::samplelib ALIAS samplelib_fuzz)
