"""Conan 2 recipe — OPTIONAL.

The fuzz harnesses build with a bare `cmake` invocation and require NO Conan
(sanitizer/fuzzer runtimes are compiler-provided). Conan is used only to supply
GoogleTest for the auxiliary decoder unit-test target; by default that target
falls back to FetchContent (BUILD_DECODER_TESTS=ON), so Conan is never required.

Use this recipe only if you prefer Conan-managed GTest:

    conan install . --output-folder build-libfuzzer --build=missing
    cmake --preset conan-... (or pass the generated toolchain)

See design §4.7.
"""

from conan import ConanFile


class CppFuzzingHarnessConan(ConanFile):
    name = "cpp-fuzzing-harness"
    version = "0.1.2"
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        # Only third-party dep: GoogleTest for the decoder unit tests.
        self.requires("gtest/1.15.0")
