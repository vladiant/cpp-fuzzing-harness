# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-04

Initial release: complete libFuzzer + AFL++ + sanitizer fuzzing demo.

### Added

- **Requirements & design docs** — lightweight SRS
  (`docs/requirements/srs.md`) and a full design specification
  (`docs/design/design.md`) establishing the single-source dual-engine
  architecture and the instrumentation-boundary ownership model.
- **Six fuzz harnesses** over `vva::SampleLib`, each a single
  `LLVMFuzzerTestOneInput` source:
  - `simple_calc_divide`, `simple_calc_arith`, `basic_operation`,
    `operation_strategy` — UB-expected targets that surface integer
    divide-by-zero via UBSan.
  - `checked_operation`, `clamped_operation` — defined-behavior targets that
    verify documented `std::exception` throws are **not** flagged as crashes
    (guarded by `FUZZ_EXPECT_DEFINED_EXCEPTIONS`).
- **Dual-engine CMake build** — a single harness source compiles for both
  libFuzzer (`-fsanitize=fuzzer`) and AFL++ (`afl-clang-fast++` + `aflpp_driver`),
  selected via the `FUZZING_ENGINE` cache option. Modular CMake helpers
  (`Sanitizers`, `FuzzingEngine`, `FetchUpstream`, `AddFuzzHarness`) make adding
  a target a one-liner.
- **Pinned upstream integration** — `vladiant/test_cpp_ci` consumed read-only
  via `FetchContent` at commit `2154ed741002263b493eb15fd8c1a419117adfa5`
  (populate-only; recompiled with this project's sanitizer/coverage flags; no
  vendoring).
- **CMake presets** — `libfuzzer-asan-ubsan` (default/acceptance),
  `afl-asan-ubsan` (CI only), and `libfuzzer-msan` (experimental). ASan+UBSan is
  the baseline; MSan is mutually exclusive with ASan and enforced as such.
- **Seed corpora & dictionaries** — per-target seed corpora, plus
  `int16_boundaries.dict` and `operations.dict` boundary-token dictionaries.
- **Decoder unit tests** — a header-only `FuzzedDataProvider`/operand decoder
  with an 11-test GoogleTest suite (`test_operand_decoder`) run via `ctest`
  under ASan+UBSan.
- **Regression corpus** — curated, minimized, permanent reproducers under
  `corpus/regression/<target>/`, kept separate from the mutable seed corpus and
  replayed non-mutatingly as the true regression gate (resolves SRS OQ-7).
- **Run & reproduction scripts** — `run_libfuzzer.sh`, `run_afl.sh`,
  `reproduce.sh`, plus the CI gates `ci_libfuzzer_gate.sh` (expected
  crash/clean) and `ci_regression_gate.sh` (deterministic `-runs=0` replay).
- **CI workflows** —
  - `fuzz-libfuzzer.yml` (PR + dispatch): build + decoder tests + short gated
    per-target runs + regression replay + an experimental, allowed-to-fail MSan
    leg. Locally verified and CI-ready.
  - `fuzz-afl.yml` (dispatch + weekly schedule): AFL++ campaign on
    `basic_operation` asserting crash rediscovery. Logic/syntax reviewed;
    **runtime pending first CI run.**
- **Optional Conan recipe** — `conanfile.py` supplying GoogleTest only; the
  build requires no Conan by default (FetchContent fallback).

### Fixed

- **D-2 hygiene** — `.gitignore` now covers libFuzzer/AFL++ run artifacts
  (`crash-*`, `leak-*`, `timeout-*`, `oom-*`, `slow-unit-*`, `findings-*/`,
  etc.), and all run/CI scripts write to a scratch output dir seeded from the
  read-only corpus, so neither local runs nor CI can mutate the tracked
  `corpus/` or commit a stray crash blob.

### Known limitations

- Signed-overflow UB does not surface at `int16_t` width (C++ integer
  promotion widens `add`/`subtract`/`multiply` to `int`; `INT16_MIN / -1` does
  not trap through the templated API). The UB consistently found is integer
  divide-by-zero. The harnesses still genuinely discover real, reproducible UB.
- The AFL++ CI job's runtime has not yet been confirmed on a live GitHub Actions
  run.

[0.1.0]: https://github.com/vladiant/cpp-fuzzing-harness/releases/tag/v0.1.0
