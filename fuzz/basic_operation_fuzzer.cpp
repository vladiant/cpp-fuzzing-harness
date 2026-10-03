/// \file basic_operation_fuzzer.cpp
/// \brief FR-3 — fuzz `vva::BasicOperationWarper` across all four operations
///        (UB EXPECTED, no guard).
///
/// `BasicOperationWarper` forwards straight to the unchecked `simple_calc`
/// templates, so `division(a, 0)` is undefined behavior (integer-divide-by-zero)
/// and must reach the sanitizer. The harness does NOT guard the calls. See the
/// per-target expectation matrix (design §6.4).

#include <cstddef>
#include <cstdint>

#include "common/fuzzed_data_provider.hpp"
#include "common/operand_decoder.hpp"

#include "basic_warper.hpp"  // vva::BasicOperationWarper

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  fuzz::FuzzedDataProvider fdp(data, size);
  const auto [a, b] = fuzz::decode_pair(fdp);
  const fuzz::Op op = fuzz::decode_op(fdp);

  vva::BasicOperationWarper warper;

  // UB-EXPECTED: no guard. Undefined behavior must reach the sanitizer.
  switch (op) {
    case fuzz::Op::Add:
      (void)warper.addition(a, b);
      break;
    case fuzz::Op::Subtract:
      (void)warper.subtraction(a, b);
      break;
    case fuzz::Op::Multiply:
      (void)warper.multiplication(a, b);
      break;
    case fuzz::Op::Divide:
      (void)warper.division(a, b);
      break;
  }
  return 0;
}
