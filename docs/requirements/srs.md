# Software Requirements Specification — cpp-fuzzing-harness

**Project:** `vladiant/cpp-fuzzing-harness` · **Document type:** Lightweight SRS (Requirement Analysis stage) · **Status:** Draft for System Architect hand-off · **Date:** 2026-10-04 · **Author role:** Requirements Analyst / Product Owner

## 1. Introduction

### 1.1 Purpose
Requirements for a **portfolio demonstration project** that showcases **coverage-guided fuzzing** of a small C++ library using **libFuzzer** and **AFL++**, combined with **LLVM/Clang sanitizers** (ASan, UBSan, and — where applicable — MSan). It demonstrates a resume-relevant skill set: fuzz-target authoring, dual-engine integration from a single harness source, sanitizer-driven bug detection, corpus/dictionary management, crash reproduction, and CI-friendly automation.

### 1.2 Scope
Harnesses target the calculator library **`SampleLib`** (namespace `vva`) from **`vladiant/test_cpp_ci`** (https://github.com/vladiant/test_cpp_ci), pinned to commit **`2154ed741002263b493eb15fd8c1a419117adfa5`**. In-scope targets:
- `simple_calc.hpp` free functions `add`/`subtract`/`multiply`/`divide` — signed-overflow & divide-by-zero UB.
- `BasicOperationWarper` (`int16_t`) — signed overflow, `INT_MIN / -1`, divide-by-zero UB.
- `CheckedOperationWarper` — throws `std::overflow_error`/`std::underflow_error`/`std::invalid_argument` on out-of-range/div-by-zero.
- `ClampedOperationWarper` — clamps results but still throws on div-by-zero.
- `OperationStrategy(IOperationWarper&)` — `operator()(a,b)` divides by `(a-b)`, so `a==b` triggers division by zero.

### 1.3 Meaning of "complementing `test_cpp_ci`"
Upstream already provides ubuntu/macos/windows builds; sanitizers (ASan/MSan/TSan/UBSan) on **unit tests**; Valgrind memcheck; coverage; static analysis; CodeQL; clang-format; clang-tidy modernize; `.deb` packaging. This project **must not duplicate** those — it **adds the fuzzing dimension upstream lacks**. Upstream validates known behaviors with example-based tests; this project explores unknown input space to surface latent bugs.

### 1.4 Definitions
SRS; FR/NFR; ASan/UBSan/MSan/TSan; libFuzzer (LLVM in-process fuzzer); AFL++; Harness (`LLVMFuzzerTestOneInput`); Corpus; Dictionary; Regression corpus; UB (Undefined Behavior).

## 2. Stakeholders & Audience
Project owner (portfolio author); reviewers/hiring managers; downstream contributors; System Architect (consumes this SRS); QA (verifies acceptance). Primary audience = **technical reviewers**; documentation quality is first-class (NFR-7).

## 3. Functional Requirements

**Fuzz targets**
- **FR-1:** Harness for `simple_calc.hpp` `divide` exercising divide-by-zero and `INT_MIN / -1`.
- **FR-2:** Harness for `simple_calc.hpp` `add`/`subtract`/`multiply` exercising signed-overflow UB.
- **FR-3:** Harness for `BasicOperationWarper` (`int16_t`) exercising signed overflow, `INT_MIN / -1`, div-by-zero.
- **FR-4:** Harness for `CheckedOperationWarper`; its defined thrown exceptions (`overflow_error`/`underflow_error`/`invalid_argument`) must **not** be reported as fuzzing failures.
- **FR-5:** Harness for `ClampedOperationWarper` verifying clamping; only div-by-zero yields a (defined) thrown exception.
- **FR-6:** Harness for `OperationStrategy(IOperationWarper&)` exercising the `a==b` → divide-by-`(a-b)` path.
> Granularity (per-target vs grouped) is deferred (OQ-5); each of FR-1…FR-6 must be independently runnable/selectable.

**Entry point & engine portability**
- **FR-7:** Each harness uses `LLVMFuzzerTestOneInput(const uint8_t*, size_t)` so the **same source** works for libFuzzer and AFL++ (`aflpp_driver`).
- **FR-8:** Each harness deterministically derives typed operands from raw buffer and handles empty/undersized input without spurious crashes.

**Build modes**
- **FR-9:** **libFuzzer build mode** per selectable target.
- **FR-10:** **AFL++ build mode** compiling the *same* harness sources per selectable target.
- **FR-11:** Both modes share source with **no per-engine code forks** of target-exercising logic (engine chosen at build-config level only).

**Sanitizer instrumentation**
- **FR-12:** Baseline = **ASan + UBSan** for all harnesses.
- **FR-13:** Document and, where feasible, provide an **MSan** variant, noting MSan needs an MSan-instrumented dependency chain and is **not combinable with ASan** in one binary (OQ-3).
- **FR-14:** Sanitizer findings / uncaught non-contract exceptions cause the fuzzer to register a crash and persist the reproducer.

**Corpora, dictionaries & reproduction**
- **FR-15:** Ship initial **seed corpus** per target (e.g., `0`, `INT16_MIN`, `INT16_MAX`, equal-operand pairs).
- **FR-16:** Provide a **dictionary** of boundary tokens/constants where helpful.
- **FR-17:** Support **crash reproduction**: persisted crashing input replays deterministically.
- **FR-18:** Maintain a **regression corpus** re-run deterministically (non-mutating) as a fast check.

**Upstream integration**
- **FR-19:** Consume `SampleLib` at pinned commit `2154ed74…`, treating upstream as read-only.
- **FR-20:** No modification/patch/vendor-copy that can drift from the pinned commit (mechanism is Architect's choice, e.g., FetchContent).

## 4. Non-Functional Requirements
- **NFR-1 Portability:** Build/run with **clang 18 + libFuzzer** locally and on GH Actions `ubuntu-latest`.
- **NFR-2 AFL++ env:** AFL++ flow supported on `ubuntu-latest` (apt `afl++` 4.09c via passwordless sudo); **not** required on local dev box.
- **NFR-3 Reproducibility:** Deterministic builds/regression runs given same toolchain, pinned commit, corpus, seed; persisted crashes reproduce reliably.
- **NFR-4 CI-friendly duration:** Each CI fuzz run time-boxed to a short, CI-appropriate duration (seconds-to-low-minutes per target; exact bound = OQ-1).
- **NFR-5 Clean separation:** Upstream integrated at pinned commit, no vendoring drift, explicit/auditable version.
- **NFR-6 Resource bounds:** Harnesses bound input-derived work so fuzzer timeouts/OOMs indicate real target issues, not harness defects.
- **NFR-7 Documentation:** Portfolio-grade docs (what fuzzing is; libFuzzer vs AFL++ here; local+CI build; crash reproduction; how it complements `test_cpp_ci`).
- **NFR-8 Maintainability:** Adding a new target follows a clear, documented pattern.
- **NFR-9 Licensing:** License compatible with portfolio reuse and with upstream's license (confirm, OQ-6).

## 5. Constraints & Assumptions
**Constraints** — C-1 upstream read-only, pinned `2154ed74…`; C-2 clang 18, libFuzzer assumed on dev + `ubuntu-latest`; C-3 **no local AFL++** (needs root), CI only; C-4 ASan+MSan cannot coexist, MSan needs instrumented deps; C-5 entry point stays `LLVMFuzzerTestOneInput`.
**Assumptions** — A-1 upstream API at pinned commit matches §1.2; A-2 `ubuntu-latest` provides/installs clang 18, libFuzzer, AFL++ 4.09c w/ passwordless sudo; A-3 single-author portfolio, no auth/privacy concerns; A-4 bug-prone upstream means fuzzers are **expected** to find crashes — surfacing/documenting (not fixing upstream) is the demo.

## 6. Out of Scope
OOS-1 modifying/patching upstream; OOS-2 duplicating existing upstream CI (unit-test sanitizers, Valgrind, coverage, static analysis, CodeQL, format/tidy, packaging, mac/win matrix); OOS-3 production/continuous fuzzing infra (OSS-Fuzz, ClusterFuzz, farms, large-scale distillation); OOS-4 engines beyond libFuzzer/AFL++; OOS-5 TSan fuzzing; OOS-6 Windows/macOS fuzzing (Linux/clang-18 only this iteration); OOS-7 architecture/build-system/CI design (later stages).

## 7. Open Questions
- **OQ-1:** Exact per-target CI time-box (e.g., `-max_total_time`)?
- **OQ-2:** Fuzz on every push/PR, on a schedule, or both?
- **OQ-3:** Is a working MSan variant required, or is documenting the caveat (ASan+UBSan only) sufficient?
- **OQ-4:** When a genuine upstream bug is found, is CI a **pass** (bug demonstrated/catalogued) or **fail** (crash present)? Affects acceptance semantics.
- **OQ-5:** Harness granularity (per-target binaries vs multiplexed) and naming convention?
- **OQ-6:** Exact upstream license, and which license this project adopts?
- **OQ-7:** Commit seed/regression corpora to the repo, generate on the fly, or both?

## 8. Acceptance Criteria
- **AC-1:** For each FR-1…FR-6, a harness exists, builds in **libFuzzer mode** (clang 18), independently runnable.
- **AC-2:** Same sources build in **AFL++ mode** (CI) with no per-engine logic forks (FR-7/10/11).
- **AC-3:** All harnesses build/run with **ASan+UBSan** (FR-12).
- **AC-4:** MSan handled per OQ-3 (variant works or caveat documented) (FR-13).
- **AC-5:** `simple_calc divide`, `BasicOperationWarper`, `OperationStrategy` harnesses surface expected UB with a persisted reproducer (FR-1/3/6/14/17).
- **AC-6:** `CheckedOperationWarper`/`ClampedOperationWarper` harnesses do **not** flag defined thrown exceptions as failures (FR-4/5).
- **AC-7:** Each target ships seed corpus (FR-15) and, where applicable, dictionary (FR-16); persisted crash replays deterministically (FR-17).
