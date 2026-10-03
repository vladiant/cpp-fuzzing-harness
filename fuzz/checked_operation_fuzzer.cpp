/// \file checked_operation_fuzzer.cpp
/// \brief FR-4 — fuzz `vva::CheckedOperationWarper` across all four operations
///        (DEFINED behavior, guarded).
///
/// `CheckedOperationWarper` has a documented contract: it THROWS on range
/// (`std::overflow_error` / `std::underflow_error`) and on division-by-zero
/// (`std::invalid_argument`). Those throws are correct, defined behavior and
/// must NOT be registered as fuzzing crashes, so every call is wrapped in
/// FUZZ_EXPECT_DEFINED_EXCEPTIONS (swallows `std::exception` only). A sanitizer
/// abort is not a C++ exception and would still crash the process. Expectation:
/// clean run (design §6.4).

#include <cstddef>
#include <cstdint>

#include "common/fuzzed_data_provider.hpp"
#include "common/harness_prelude.hpp"
#include "common/operand_decoder.hpp"

#include "checked_warper.hpp"  // vva::CheckedOperationWarper

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  fuzz::FuzzedDataProvider fdp(data, size);
  const auto [a, b] = fuzz::decode_pair(fdp);
  const fuzz::Op op = fuzz::decode_op(fdp);

  vva::CheckedOperationWarper warper;

  // DEFINED: swallow the documented std::exception throws (range / div-by-zero).
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
