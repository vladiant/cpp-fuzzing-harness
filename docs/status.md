# Project Status — cpp-fuzzing-harness

**SDLC stage:** Maintenance patch ready to tag — `v0.1.1` (prev. released `v0.1.0`).
**Date:** 2026-10-04
**Version:** `0.1.0` released; `0.1.1` patch pending version bump + tag (Release step).
**Next step:** bump `VERSION` to `0.1.1` and tag `v0.1.1`, then trigger the
AFL++ CI job to confirm its runtime on a live GitHub Actions run (configure-time
driver discovery is now fixed; only live-runtime confirmation remains).

## Summary

A portfolio demonstration of coverage-guided fuzzing (libFuzzer + AFL++) with
Clang sanitizers (ASan+UBSan baseline; MSan experimental), applied to
`vva::SampleLib` from the upstream `vladiant/test_cpp_ci` project (consumed
read-only via FetchContent at pinned commit
`2154ed741002263b493eb15fd8c1a419117adfa5`). It complements upstream CI by
adding the fuzzing dimension upstream lacks.

## Maintenance patch (0.1.1)

A post-release fix for the AFL++ CI configure failure: a variable-name
collision in `cmake/FuzzingEngine.cmake` made `find_library` reuse the
pre-declared (empty-but-set) `AFL_DRIVER_PATH` cache entry and silently skip
auto-discovery, so configuring an AFL++ build failed with
`AFL++ driver ... not found` even when the driver was present at a searched
path. Discovery now resolves into distinct internal variables;
`AFL_DRIVER_PATH` is kept solely as the explicit user override. Verified by a
mock proof (auto-discovery resolves; `-DAFL_DRIVER_PATH=` override still works),
the libFuzzer regression (UB crash, `checked_operation` clean, 11/11 decoder
ctest), and the non-AFL-compiler guard rail still firing. The live AFL++
runtime on GitHub Actions is still pending re-confirmation post-fix.

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
| AFL++ configure-time driver discovery (`cmake/FuzzingEngine.cmake`) | ✅ Fixed in 0.1.1 (mock proof + libFuzzer regression) |
| AFL++ CI job runtime (`fuzz-afl.yml`) | ⏳ Pending live CI re-confirmation post-fix |
| MSan path | 🧪 Experimental (needs instrumented libc++; allowed-to-fail CI leg) |

## Known limitations

- Signed-overflow UB does not surface at `int16_t` width (integer promotion
  widens to `int`); the UB consistently found is integer divide-by-zero. The
  harnesses still genuinely find real, reproducible UB.
- AFL++ remains CI-only and runtime-unconfirmed.

## Note for the release tagger

- Suggested tag: **`0.1.1`** — a maintenance patch over `0.1.0` (AFL++
  configure-time driver discovery fix); bump `VERSION`,
  `project(... VERSION 0.1.1)` in `CMakeLists.txt`, and `version = "0.1.1"` in
  `conanfile.py` to match.
- The `CHANGELOG.md` already carries a dated `0.1.1` section and comparison
  link; no further CHANGELOG edits needed before tagging.
- Call out in release notes that the AFL++ **configure-time** driver discovery
  bug is fixed and verified (mock + libFuzzer regression), but the **live AFL++
  runtime** on GitHub Actions is still pending re-confirmation — so expectations
  are set honestly.
