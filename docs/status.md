# Project Status — cpp-fuzzing-harness

**SDLC stage:** Released — initial version tagged `v0.1.0`.
**Date:** 2026-10-04
**Version:** `0.1.0` (see `VERSION`; annotated tag `v0.1.0`).
**Next step:** push the `v0.1.0` tag, then trigger the AFL++ CI job to
confirm its runtime on a live GitHub Actions run.

## Summary

A portfolio demonstration of coverage-guided fuzzing (libFuzzer + AFL++) with
Clang sanitizers (ASan+UBSan baseline; MSan experimental), applied to
`vva::SampleLib` from the upstream `vladiant/test_cpp_ci` project (consumed
read-only via FetchContent at pinned commit
`2154ed741002263b493eb15fd8c1a419117adfa5`). It complements upstream CI by
adding the fuzzing dimension upstream lacks.

## What shipped

- SRS + design specification (`docs/requirements/srs.md`, `docs/design/design.md`).
- Six single-source, dual-engine fuzz harnesses over `SampleLib`:
  - UB-expected: `simple_calc_divide`, `simple_calc_arith`, `basic_operation`,
    `operation_strategy`.
  - Defined-behavior (stay-clean): `checked_operation`, `clamped_operation`.
- Dual-engine CMake (libFuzzer + AFL++) with pinned, populate-only FetchContent
  integration and modular CMake helpers; three presets
  (`libfuzzer-asan-ubsan`, `afl-asan-ubsan`, `libfuzzer-msan`).
- Seed corpora, two dictionaries, and a separate curated regression corpus.
- Header-only decoder with an 11-test GoogleTest suite.
- Run/reproduction scripts and CI gate scripts.
- Two CI workflows (`fuzz-libfuzzer.yml`, `fuzz-afl.yml`).
- D-2 hygiene fix (gitignore + scratch-dir run isolation).
- README, CHANGELOG, and this status doc.

## Verified vs. pending

| Item | State |
|------|-------|
| libFuzzer build (preset `libfuzzer-asan-ubsan`), all 6 targets | ✅ Verified (QA, clean build) |
| Decoder unit tests (11) via `ctest` under ASan+UBSan | ✅ Verified (11/11 pass) |
| UB-expected targets crash (UBSan div-by-zero, exit 77) | ✅ Verified |
| Defined-behavior targets stay clean (50k runs) | ✅ Verified |
| Deterministic reproduction + non-mutating regression replay | ✅ Verified |
| CMake guard rails (engine/sanitizer exclusivity) | ✅ Verified |
| `fuzz-libfuzzer.yml` (build + unit + gated runs + regression) | ✅ Locally verified / CI-ready |
| AFL++ CI job runtime (`fuzz-afl.yml`) | ⏳ Pending first live CI run (logic/syntax reviewed only) |
| MSan path | 🧪 Experimental (needs instrumented libc++; allowed-to-fail CI leg) |

## Known limitations

- Signed-overflow UB does not surface at `int16_t` width (integer promotion
  widens to `int`); the UB consistently found is integer divide-by-zero. The
  harnesses still genuinely find real, reproducible UB.
- AFL++ remains CI-only and runtime-unconfirmed.

## Note for the release tagger

- Suggested tag: **`0.1.0`** — matches `project(... VERSION 0.1.0)` in
  `CMakeLists.txt` and `version = "0.1.0"` in `conanfile.py`; it is the first
  release of a complete, QA-passed feature set.
- Move the `Unreleased` section of `CHANGELOG.md` under a `0.1.0` heading dated
  on tag day, and update the comparison links.
- Call out in release notes that the **AFL++ CI job is pending its first live
  run** so expectations are set honestly.
