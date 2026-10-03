/// \file simple_calc_divide_fuzzer.cpp
/// \brief FR-1 — fuzz `vva::divide<int16_t>` directly (UB EXPECTED, no guard).
///
/// Integer division-by-zero (`b == 0`) is undefined behavior and must reach the
/// sanitizer, so this harness calls the target WITHOUT any try/catch. UBSan
/// (integer-divide-by-zero) surfaces the finding and libFuzzer persists the
/// reproducer. See the per-target expectation matrix (design §6.4).

#include <cstddef>
#include <cstdint>

#include "common/fuzzed_data_provider.hpp"
#include "common/operand_decoder.hpp"

#include "simple_calc.hpp"  // vva::divide (header-only template)

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  fuzz::FuzzedDataProvider fdp(data, size);
  const auto [a, b] = fuzz::decode_pair(fdp);

  // UB-EXPECTED: no guard. divide(x, 0) and INT16_MIN/-1 reach the sanitizer.
  (void)vva::divide<int16_t>(a, b);
  return 0;
}
