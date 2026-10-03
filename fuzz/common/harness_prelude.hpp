#ifndef FUZZ_COMMON_HARNESS_PRELUDE_HPP
#define FUZZ_COMMON_HARNESS_PRELUDE_HPP

/// \file harness_prelude.hpp
/// \brief Shared harness idioms that make the DEFINED-vs-UB contract explicit
///        and greppable (design §3.3).

#include <exception>

/// Evaluate `expr` and swallow ONLY `std::exception`. Used by the DEFINED-
/// behavior targets (CheckedOperationWarper / ClampedOperationWarper) whose
/// documented contract is to `throw` on range/zero inputs — those throws are
/// correct behavior and must NOT register as fuzzing crashes (FR-4/FR-5).
///
/// A sanitizer abort (ASan/UBSan) is NOT a C++ exception and therefore is NOT
/// swallowed by this macro: real memory/UB findings still crash the process.
///
/// For UB-expected targets we deliberately do NOT wrap the call, so undefined
/// behavior reaches the sanitizer. Encoding the contract as a named macro keeps
/// the intent explicit and prevents accidentally masking a real finding behind
/// a stray try/catch.
#define FUZZ_EXPECT_DEFINED_EXCEPTIONS(expr) \
  try {                                      \
    (void)(expr);                            \
  } catch (const std::exception&) {          \
    /* defined behavior: documented throw */ \
  }

#endif  // FUZZ_COMMON_HARNESS_PRELUDE_HPP
