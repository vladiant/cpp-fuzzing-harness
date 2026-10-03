/// \file operation_strategy_fuzzer.cpp
/// \brief FR-6 — fuzz `vva::OperationStrategy` over an injected
///        `BasicOperationWarper` (UB EXPECTED, no guard).
///
/// `OperationStrategy::operator()(a, b)` computes `2*(a+b) / (a-b)` through the
/// injected warper. When `a == b` the divisor `(a - b)` is zero, so the
/// underlying `BasicOperationWarper::division` performs integer-divide-by-zero
/// — undefined behavior that must reach the sanitizer. The collaborator is
/// constructed on the stack and injected by reference (dependency injection, no
/// registry). The call is NOT guarded. Expectation: crash (design §6.4).

#include <cstddef>
#include <cstdint>

#include "common/fuzzed_data_provider.hpp"
#include "common/operand_decoder.hpp"

#include "basic_warper.hpp"        // vva::BasicOperationWarper
#include "operation_strategy.hpp"  // vva::OperationStrategy

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  fuzz::FuzzedDataProvider fdp(data, size);
  const auto [a, b] = fuzz::decode_pair(fdp);

  vva::BasicOperationWarper warper;
  vva::OperationStrategy strategy(warper);

  // UB-EXPECTED: no guard. a == b drives division-by-zero into the sanitizer.
  (void)strategy(a, b);
  return 0;
}
