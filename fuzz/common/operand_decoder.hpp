#ifndef FUZZ_COMMON_OPERAND_DECODER_HPP
#define FUZZ_COMMON_OPERAND_DECODER_HPP

/// \file operand_decoder.hpp
/// \brief Deterministic byte-stream -> typed int16_t operand mapping for the
///        SampleLib harnesses (design §3.2).
///
/// All decoding is pure, bounded, and allocation-free so that fuzzer
/// timeouts/OOMs always indicate real target issues (NFR-6), and identical
/// bytes always map to identical operands (reproducibility, FR-17/NFR-3).

#include <cstdint>

#include "fuzzed_data_provider.hpp"

namespace fuzz {

/// A decoded operand pair for the binary SampleLib operations.
struct OperandPair {
  int16_t a;
  int16_t b;
};

/// Operation selector for multiplexed harnesses (FR-2).
enum class Op : uint8_t { Add = 0, Subtract = 1, Multiply = 2, Divide = 3 };

/// Pulls two `int16_t` operands (little-endian) from the stream. Exhausted bytes
/// decode to zero, so even an empty buffer yields the well-defined pair (0, 0).
inline OperandPair decode_pair(FuzzedDataProvider& fdp) noexcept {
  OperandPair pair;
  pair.a = fdp.consume_integral<int16_t>();
  pair.b = fdp.consume_integral<int16_t>();
  return pair;
}

/// Extracts a 0..3 operation selector (add/subtract/multiply/divide).
inline Op decode_op(FuzzedDataProvider& fdp) noexcept {
  return static_cast<Op>(fdp.consume_byte() & 0x03u);
}

}  // namespace fuzz

#endif  // FUZZ_COMMON_OPERAND_DECODER_HPP
