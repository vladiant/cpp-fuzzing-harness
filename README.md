# cpp-fuzzing-harness

[![fuzz-libfuzzer](https://github.com/vladiant/cpp-fuzzing-harness/actions/workflows/fuzz-libfuzzer.yml/badge.svg)](https://github.com/vladiant/cpp-fuzzing-harness/actions/workflows/fuzz-libfuzzer.yml)
[![fuzz-afl](https://github.com/vladiant/cpp-fuzzing-harness/actions/workflows/fuzz-afl.yml/badge.svg)](https://github.com/vladiant/cpp-fuzzing-harness/actions/workflows/fuzz-afl.yml)

A portfolio demonstration of **coverage-guided fuzzing** (libFuzzer **and**
AFL++) combined with **LLVM/Clang sanitizers** (AddressSanitizer + Undefined
Behavior Sanitizer as the baseline; MemorySanitizer as an experimental option),
applied to a small C++ calculator library.

> **AFL++ CI status note:** the libFuzzer suite and the regression gate are
> locally verified and CI-ready. The AFL++ CI job has been reviewed for
> logic/syntax but **its runtime has not yet been confirmed on a real GitHub
> Actions run** — it is marked experimental / *pending first CI run* throughout
> this document.

---

## What skill does this demonstrate?

This repository is a focused showcase of fuzzing-engineer fundamentals:

- **Fuzz-target authoring** — six harnesses over a real third-party API, each
  encoding an explicit *crash-expected vs. stay-clean* contract.
- **Single-source, dual-engine integration** — the *same* `LLVMFuzzerTestOneInput`
  source compiles for both libFuzzer (`-fsanitize=fuzzer`) and AFL++
  (`afl-clang-fast++` + the `aflpp_driver`); the engine is a build-configuration
  choice, never a source fork.
- **Sanitizer-driven bug detection** — ASan+UBSan instrumentation applied
  seamlessly across the instrumentation boundary (both the code under test and
  the harnesses), so real undefined behavior is caught and documented-defined
  exceptions are not falsely flagged.
- **Corpus & dictionary management** — seed corpora, boundary-token
  dictionaries, and a separate, curated regression corpus.
- **Deterministic crash reproduction** — a replay script plus a non-mutating
  regression gate.
- **CI-friendly automation** — time-boxed, gated fuzz runs wired into GitHub
  Actions.

## How it complements `vladiant/test_cpp_ci`

The library under test, `SampleLib` (namespace `vva`), comes from the upstream
CI project
[`vladiant/test_cpp_ci`](https://github.com/vladiant/test_cpp_ci), pinned at
commit `2154ed741002263b493eb15fd8c1a419117adfa5`. Upstream already provides
multi-platform builds, sanitizers on **example-based unit tests**, Valgrind,
coverage, static analysis, CodeQL, clang-format/clang-tidy, and `.deb`
packaging.

This project deliberately **does not duplicate** any of that. It adds the one
dimension upstream lacks: **coverage-guided fuzzing** that *explores* the input
space to surface latent undefined behavior, rather than *validating* known
behaviors with hand-written examples. Upstream is consumed **read-only** via
CMake `FetchContent` at the pinned commit — no vendoring, no patches, no drift.

## Architecture summary

```
Upstream (FetchContent, pinned 2154ed74, read-only)
  lib/include/*.hpp + lib/src/*.cpp
        │   recompiled with THIS project's sanitizer/coverage flags
        ▼
  samplelib_fuzz  (instrumented STATIC lib)
        │                     fuzz_common (header-only decoder + prelude)
        ▼                           │
  *_fuzzer.cpp  (one LLVMFuzzerTestOneInput source per target) ◄──┘
        │   link-time engine choice
        ▼
  -fsanitize=fuzzer (libFuzzer)  |  libAFLDriver.a (AFL++)
        ▼
  fuzz_<name>_<engine> executables  ◄── corpus/ seeds + dictionaries/ tokens
```

Key design decisions: upstream is *populated* (not `MakeAvailable`'d) so its
app/test/coverage targets are not inherited, and it is recompiled with the same
instrumentation as the harnesses — there is no "library instrumented, harness
not" gap. The only logic this repo owns is the header-only byte decoder, which
is the only part with its own unit tests.

Full details: [`docs/design/design.md`](docs/design/design.md). Requirements:
[`docs/requirements/srs.md`](docs/requirements/srs.md). QA verification:
[`docs/testing/cpp-fuzzing-harness-test-report.md`](docs/testing/cpp-fuzzing-harness-test-report.md).
Project status: [`docs/status.md`](docs/status.md).

## Prerequisites / toolchain

| Tool | libFuzzer path (local + CI) | AFL++ path (CI only) |
|------|-----------------------------|----------------------|
| Compiler | clang 18 (`/usr/bin/clang++`) | `afl-clang-fast++` |
| Fuzzing engine | libFuzzer (shipped with clang) | AFL++ (apt `afl++` 4.09c) |
| Build | CMake ≥ 3.24 + Ninja | CMake ≥ 3.24 + Ninja |
| Unit tests | GoogleTest (via FetchContent, or Conan — optional) | — |

AFL++ needs root to install and is therefore **CI-only**; a plain clang-18 box
builds and runs the entire libFuzzer path with no AFL dependency at all.
`conanfile.py` is **optional** — it only supplies GoogleTest for the decoder
tests, which otherwise fall back to FetchContent.

## Quickstart

### libFuzzer (default path)

Using CMake presets:

```bash
cmake --preset libfuzzer-asan-ubsan
cmake --build --preset libfuzzer-asan-ubsan --parallel

# Run the decoder unit tests (11 tests, under ASan+UBSan)
ctest --preset libfuzzer-asan-ubsan --output-on-failure -j"$(nproc)"

# Time-box one target (configure + build + run, scratch output dir)
scripts/run_libfuzzer.sh simple_calc_divide -max_total_time=30
```

Plain CMake (no presets):

```bash
cmake -S . -B build-libfuzzer -G Ninja \
      -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
      -DFUZZING_ENGINE=libfuzzer -DENABLE_ASAN=ON -DENABLE_UBSAN=ON
cmake --build build-libfuzzer --parallel

# Run a target directly (seed corpus + dictionary)
./build-libfuzzer/simple_calc_divide corpus/simple_calc_divide \
    -dict=dictionaries/int16_boundaries.dict \
    -max_total_time=30 -max_len=16
```

### AFL++ (CI only — pending first CI run)

Using presets (requires `afl-clang-fast++` and `libAFLDriver.a`):

```bash
cmake --preset afl-asan-ubsan
cmake --build --preset afl-asan-ubsan --parallel

# Configure + build + run one target for 60s
scripts/run_afl.sh basic_operation -V 60
```

Plain CMake:

```bash
cmake -S . -B build-afl -G Ninja \
      -DCMAKE_CXX_COMPILER=afl-clang-fast++ \
      -DFUZZING_ENGINE=afl -DENABLE_ASAN=ON -DENABLE_UBSAN=ON \
      -DBUILD_DECODER_TESTS=OFF
cmake --build build-afl --parallel
```

## Reproducing a crash

Persisted reproducers live under `corpus/regression/<target>/` (see
[`corpus/regression/README.md`](corpus/regression/README.md)). Replay one
deterministically with the libFuzzer build:

```bash
# Build the libFuzzer targets first (preset or run_libfuzzer.sh), then:
scripts/reproduce.sh simple_calc_divide \
  corpus/regression/simple_calc_divide/divzero_a1_b0
```

Replay a whole regression set for a target (no fuzzing, no mutation):

```bash
./build-libfuzzer/basic_operation corpus/regression/basic_operation -runs=0
```

For a UB target the replay is **expected to crash** (UBSan division-by-zero,
exit 77) — that is the regression signal that the catalogued UB still
reproduces.

## Harness catalog

All harnesses decode two little-endian `int16_t` operands (and, where
applicable, a `& 0x03` op-selector byte) from the fuzzer buffer via
`fuzz/common/operand_decoder.hpp`.

| Target | Upstream API exercised | Guard | Expected outcome |
|--------|------------------------|-------|------------------|
| `simple_calc_divide` | `vva::divide<int16_t>` | none (UB-expected) | **Crash** — UBSan integer divide-by-zero (exit 77) |
| `simple_calc_arith` | `vva::add/subtract/multiply/divide` (op-selected) | none (UB-expected) | **Crash** — UBSan divide-by-zero via the `Divide` selector |
| `basic_operation` | `vva::BasicOperationWarper` (all 4 ops) | none (UB-expected) | **Crash** — UBSan divide-by-zero in `division()` |
| `operation_strategy` | `vva::OperationStrategy` over `BasicOperationWarper` | none (UB-expected) | **Crash** — UBSan divide-by-zero when `a == b` (divisor `a-b == 0`) |
| `checked_operation` | `vva::CheckedOperationWarper` (all 4 ops) | `FUZZ_EXPECT_DEFINED_EXCEPTIONS` | **Clean** — documented `std::exception` throws are swallowed |
| `clamped_operation` | `vva::ClampedOperationWarper` (all 4 ops) | `FUZZ_EXPECT_DEFINED_EXCEPTIONS` | **Clean** — clamp paths never throw; div-by-zero throw swallowed |

The `FUZZ_EXPECT_DEFINED_EXCEPTIONS` macro (`fuzz/common/harness_prelude.hpp`)
swallows **only** `std::exception`. A sanitizer abort is not a C++ exception and
is therefore never masked — a real memory/UB finding on a "clean" target would
still crash the process.

## Corpus & dictionary layout

```
corpus/
├── <target>/              # mutable seed corpus per target (e.g. zero_zero, int16min_neg1)
└── regression/            # curated, minimized, PERMANENT reproducers (replay-only)
    ├── README.md          # byte layout + expected UB per seed
    └── <ub-target>/

dictionaries/
├── int16_boundaries.dict  # int16 corner values as little-endian byte pairs
└── operations.dict        # op-selector bytes for the multiplexed arith harness
```

The regression corpus is kept **separate** from the mutable seed corpus so a
live fuzz run can never mutate the permanent reproducers.

## Sanitizer notes

- **Default: ASan + UBSan** (preset `libfuzzer-asan-ubsan`). This is the
  acceptance path and what CI runs. UBSan is built with
  `-fno-sanitize-recover=undefined`, so the first undefined-behavior finding
  aborts the process.
- **MSan is experimental** (preset `libfuzzer-msan`). MemorySanitizer is
  mutually exclusive with ASan (the build enforces this with a `FATAL_ERROR`)
  and needs an MSan-instrumented libc++ to avoid false positives from
  uninstrumented standard-library code. It is provided as a documented option
  and runs only as a manual, allowed-to-fail CI leg — do not treat its findings
  as authoritative without an instrumented dependency chain.

## CI overview

Two GitHub Actions workflows, each adding only the fuzzing dimension (no
duplication of upstream CI):

- **[`fuzz-libfuzzer.yml`](.github/workflows/fuzz-libfuzzer.yml)** — runs on pull
  requests and manual dispatch. **Verified / green locally and CI-ready.**
  - `libfuzzer-asan-ubsan`: builds all six harnesses, runs the 11-test decoder
    suite via `ctest`, then a short, gated libFuzzer run per target — UB targets
    must crash within budget; `checked`/`clamped` must stay clean.
  - `regression`: deterministic `-runs=0` replay of the curated
    `corpus/regression/*` reproducers — the true regression gate.
  - `msan-experimental`: manual-dispatch only, allowed-to-fail (see MSan note).
  - All runs use a scratch output dir so the tracked `corpus/` is never mutated.
- **[`fuzz-afl.yml`](.github/workflows/fuzz-afl.yml)** — runs on manual dispatch
  and a weekly schedule (Mondays 04:17 UTC). Installs AFL++ 4.09c, runs a
  time-boxed (`-V 60`) campaign on `basic_operation`, and asserts at least one
  crash is rediscovered. **Pending first CI run** — logic/syntax reviewed, not
  yet confirmed on a live Actions runner.

## Limitations / scope notes

- **Signed-overflow UB does not surface at int16 width.** The upstream
  `simple_calc` functions are `template<typename T> T op(const T&, const T&)`.
  Instantiated at `int16_t`, C++ integer promotion widens `add`/`subtract`/
  `multiply` arithmetic to `int`, so they cannot signed-overflow; the narrowing
  store back to `int16_t` is implementation-defined, not undefined behavior.
  `INT16_MIN / -1` likewise does not trap through the templated API for the same
  reason. The undefined behavior that **does** fire reliably on every UB target
  is **integer divide-by-zero** — the harnesses still genuinely find real,
  reproducible UB; it is just consistently div-by-zero rather than overflow.
- **AFL++ is CI-only and not yet runtime-verified** (see status note above).
- **Scope is intentionally narrow:** Linux + clang-18, libFuzzer/AFL++ only. No
  Windows/macOS fuzzing, no TSan fuzzing, no production/continuous-fuzzing
  infrastructure (OSS-Fuzz/ClusterFuzz) — those are explicitly out of scope per
  the SRS.

## License

[MIT](LICENSE) © 2026 Vladislav Antonov. Upstream `test_cpp_ci` is consumed
read-only at the pinned commit and is not redistributed by this repository.
