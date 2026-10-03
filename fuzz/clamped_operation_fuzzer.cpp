/// \file clamped_operation_fuzzer.cpp
/// \brief FR-5 — fuzz `vva::ClampedOperationWarper` across all four operations
///        (DEFINED behavior, guarded).
///
/// `ClampedOperationWarper` clamps on overflow (no throw) and throws only on
/// division-by-zero (`std::invalid_argument`). Both paths are defined behavior,
/// so every call is wrapped in FUZZ_EXPECT_DEFINED_EXCEPTIONS to swallow the
/// documented div-by-zero throw. A sanitizer abort is not a C++ exception and
/// would still crash. Expectation: clean run (design §6.4).

#include <cstddef>
#include <cstdint>

#include "common/fuzzed_data_provider.hpp"
#include "common/harness_prelude.hpp"
#include "common/operand_decoder.hpp"

#include "clamped_warper.hpp"  // vva::ClampedOperationWarper

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  fuzz::FuzzedDataProvider fdp(data, size);
  const auto [a, b] = fuzz::decode_pair(fdp);
  const fuzz::Op op = fuzz::decode_op(fdp);

  vva::ClampedOperationWarper warper;

  // DEFINED: clamp paths never throw; div-by-zero throws std::invalid_argument.
  switch (op) {
    case fuzz::Op::Add:
      FUZZ_EXPECT_DEFINED_EXCEPTIONS(warper.addition(a, b));
      break;
    case fuzz::Op::Subtract:
      FUZZ_EXPECT_DEFINED_EXCEPTIONS(warper.subtraction(a, b));
      break;
    case fuzz::Op::Multiply:
      FUZZ_EXPECT_DEFINED_EXCEPTIONS(warper.multiplication(a, b));
      break;
    case fuzz::Op::Divide:
      FUZZ_EXPECT_DEFINED_EXCEPTIONS(warper.division(a, b));
      break;
  }
  return 0;
}
