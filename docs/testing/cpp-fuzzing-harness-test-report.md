# QA Test Report — cpp-fuzzing-harness

**Stage:** Testing · **Date:** 2026-10-04 · **Toolchain:** clang 18.1.3 (`/usr/bin/clang++`), cmake 3.28.3, ninja · **Engine:** libFuzzer (AFL++ deferred to CI — not installable locally).

## 1. Scope verified
Independent verification of the six fuzz harnesses against SRS acceptance
criteria AC-1…AC-7 and design §6.4 (expectation matrix) / §5.3 (regression &
reproduction). AFL++ runtime verification is out of local scope (no root); only
the AFL++ CMake guard path was exercised.

## 2. Build & unit tests
- Clean configure + build via preset `libfuzzer-asan-ubsan` (ASan+UBSan,
  clang-18): **all six targets + decoder test built with zero warnings/errors.**
- `ctest` decoder suite (`test_operand_decoder`): **11/11 passed**, under
  ASan+UBSan. No flaky/skipped tests.

Reproduce:
```bash
rm -rf build-libfuzzer
cmake --preset libfuzzer-asan-ubsan
cmake --build --preset libfuzzer-asan-ubsan
ctest --preset libfuzzer-asan-ubsan --output-on-failure -j"$(nproc)"
```

## 3. Expectation matrix (AC-5 / AC-6) — verified
Env: `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1:abort_on_error=1`,
`ASAN_OPTIONS=abort_on_error=1:halt_on_error=1`.

| Target | Expectation | Result |
|--------|-------------|--------|
| `simple_calc_divide` | crash | **UBSan div-by-zero** `simple_calc.hpp:22:12`, exit 77 ✅ |
| `simple_calc_arith` | crash | **UBSan div-by-zero** via `Divide` selector, exit 77 ✅ |
| `basic_operation` | crash | **UBSan div-by-zero** in `BasicOperationWarper::division`, exit 77 ✅ |
| `operation_strategy` | crash | **UBSan div-by-zero** via `(a-b)==0`, exit 77 ✅ |
| `checked_operation` | clean | 50000 runs / 15 s, **exit 0**, no sanitizer error, 0 crash files ✅ |
| `clamped_operation` | clean | 50000 runs / 15 s, **exit 0**, no sanitizer error, 0 crash files ✅ |

Each UB target also **independently discovered and persisted a reproducer** from
a cold start (`-max_total_time=20 -max_len=16`, empty corpus, run in scratch
dir): libFuzzer wrote `crash-<hash>` for all four. Clean targets ran the
CI-sized budget via:
```bash
./build-libfuzzer/checked_operation corpus/checked_operation \
  -runs=50000 -max_total_time=15 -max_len=16
```

## 4. Deterministic reproduction (AC-7, FR-17) — verified
`scripts/reproduce.sh <target> <file>` replays a single input; re-running the
same input yields the **identical** UBSan report and exit 77 on repeat runs. The
`-runs=0` whole-corpus regression mode is **non-mutating** (no new corpus files
written over a clean corpus; verified on `checked_operation`).

## 5. Regression corpus (FR-18, design §5.3) — added
Resolved SRS **OQ-7** by committing a curated, minimized reproducer per UB
target under **`corpus/regression/<target>/`** (documented in
`corpus/regression/README.md`). Each is 4–5 bytes and reproduces UBSan
division-by-zero (exit 77):

| Seed | Bytes | Decoded |
|------|-------|---------|
| `simple_calc_divide/divzero_a1_b0` | `01 00 00 00` | a=1, b=0 |
| `simple_calc_arith/divzero_a1_b0_opdiv` | `01 00 00 00 03` | a=1, b=0, op=Divide |
| `basic_operation/divzero_a1_b0_opdiv` | `01 00 00 00 03` | a=1, b=0, op=Divide |
| `operation_strategy/equaldiv_a1_b1` | `01 00 01 00` | a=1, b=1 (a==b) |

Kept separate from the mutable seed corpus so a live fuzz run cannot mutate the
permanent regression set.

## 6. CMake guard rails (task 5) — verified
| Guard | Result |
|-------|--------|
| `-DFUZZING_ENGINE=afl` with `/usr/bin/clang++` | `FATAL_ERROR` "requires an AFL++ compiler", configure fails (exit 1) ✅ |
| `-DENABLE_MSAN=ON -DENABLE_ASAN=ON` | `FATAL_ERROR` "mutually exclusive", configure fails (exit 1) ✅ |
| `-DFUZZING_ENGINE=bogus` (bonus) | `FATAL_ERROR` "must be 'libfuzzer' or 'afl'" ✅ |
| Default libFuzzer configure | unaffected, configures & builds ✅ |

## 7. Defects / observations
- **D-1 (non-blocking, matches developer R-1):** Signed-overflow UB for
  add/subtract/multiply does **not** fire at int16 width — the upstream templates
  are instantiated at `int16_t` and integer promotion widens arithmetic to `int`,
  and the narrowing store back to `int16_t` is implementation-defined, not UB.
  The only UB that fires on every UB target is **integer-divide-by-zero**.
  *Verdict:* AC-5 intent is still satisfied — each of the four UB targets
  surfaces a real, reproducible UB with a persisted reproducer. The harness
  comments already document this accurately. `INT16_MIN/-1` (claimed "overflow
  edge" in design §5.1) likewise does not trap for the same reason; the seed is
  harmless but not a UB trigger.
- **D-2 (non-blocking, hygiene):** `.gitignore` covers build dirs (`build-*/`)
  but **not** libFuzzer/AFL run artifacts. A UB-target fuzz/`-runs=0` run from the
  repo root drops a `crash-<hash>` blob into the working tree, and libFuzzer
  grows the **tracked** seed corpus by writing new units into
  `corpus/<target>/` when it is used as the writable corpus dir (observed during
  testing; cleaned up). Artifacts are untracked so they won't auto-commit, but
  `git status` becomes noisy and a careless `git add -A` could commit crash blobs.
  *Recommend:* add `crash-*`, `leak-*`, `timeout-*`, `oom-*`, `findings-*/` to
  `.gitignore`, and/or have the run scripts use a dedicated corpus-output dir
  (`-artifact_prefix=` + separate growth corpus) rather than the tracked seed
  corpus. Not applied here (reported for the developer/Release Engineer).

## 8. Verdict
**PASS** for release on the libFuzzer path. No blocking defects. D-1 is expected
and documented; D-2 is a hygiene recommendation. AFL++ runtime remains to be
validated in CI; the AFL++ CMake path is correctly guarded.
