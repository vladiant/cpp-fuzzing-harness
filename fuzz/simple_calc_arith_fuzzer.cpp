/// \file simple_calc_arith_fuzzer.cpp
/// \brief FR-2 — multiplexed fuzzing of the `vva::simple_calc` free functions
///        (add/subtract/multiply/divide) selected by a byte (UB EXPECTED,
///        no guard).
///
/// Implementation note (R-1 API reality): the upstream `simple_calc` functions
/// are `template<typename T> T op(const T&, const T&)`. With `int16_t` operands
/// C++ integer promotion widens to `int`, so add/subtract/multiply cannot
/// overflow at int16 width — the signed-overflow the design anticipated here
/// does not occur for this templated API. The undefined behavior that DOES fire
/// is integer-divide-by-zero via the `Divide` selector. The harness exercises
/// the full `decode_op` range (0..3) without guarding so any UB reaches the
/// sanitizer. See design §3.2 (decode_op enumerates all four ops) and §6.4.

#include <cstddef>
#include <cstdint>

#include "common/fuzzed_data_provider.hpp"
#include "common/operand_decoder.hpp"

#include "simple_calc.hpp"  // vva::add/subtract/multiply/divide (templates)

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  fuzz::FuzzedDataProvider fdp(data, size);
  const auto [a, b] = fuzz::decode_pair(fdp);
  const fuzz::Op op = fuzz::decode_op(fdp);

  // UB-EXPECTED: no guard. Any undefined behavior must reach the sanitizer.
  switch (op) {
    case fuzz::Op::Add:
      (void)vva::add<int16_t>(a, b);
      break;
    case fuzz::Op::Subtract:
      (void)vva::subtract<int16_t>(a, b);
      break;
    case fuzz::Op::Multiply:
      (void)vva::multiply<int16_t>(a, b);
      break;
    case fuzz::Op::Divide:
      (void)vva::divide<int16_t>(a, b);
      break;
  }
  return 0;
}
