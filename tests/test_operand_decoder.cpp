/// \file test_operand_decoder.cpp
/// \brief GoogleTest coverage for the header-only FuzzedDataProvider / operand
///        decoder — the only logic this repo owns (design §3.2, NFR-6).
///
/// Verifies: 0-fill on exhaustion, little-endian ordering, boundary round-trips,
/// determinism, op-selector masking, and the null/empty-input contract.

#include <array>
#include <cstdint>
#include <limits>

#include "fuzzed_data_provider.hpp"
#include "operand_decoder.hpp"

#include <gtest/gtest.h>

namespace {

using fuzz::FuzzedDataProvider;
using fuzz::Op;

// --- FuzzedDataProvider::consume_integral -----------------------------------

TEST(FuzzedDataProvider, LittleEndianInt16) {
  const std::array<uint8_t, 2> bytes{0x34, 0x12};  // 0x1234 little-endian
  FuzzedDataProvider fdp(bytes.data(), bytes.size());
  EXPECT_EQ(fdp.consume_integral<int16_t>(), static_cast<int16_t>(0x1234));
  EXPECT_EQ(fdp.remaining(), 0u);
}

TEST(FuzzedDataProvider, ZeroFillOnExhaustionEmpty) {
  // Empty buffer must not crash and must deterministically decode to zero.
  FuzzedDataProvider fdp(nullptr, 0);
  EXPECT_EQ(fdp.consume_integral<int16_t>(), int16_t{0});
  EXPECT_EQ(fdp.consume_byte(), uint8_t{0});
  EXPECT_EQ(fdp.remaining(), 0u);
}

TEST(FuzzedDataProvider, ZeroFillOnExhaustionPartial) {
  // Only one byte available for a two-byte read -> high byte is zero-filled.
  const std::array<uint8_t, 1> bytes{0xFF};
  FuzzedDataProvider fdp(bytes.data(), bytes.size());
  EXPECT_EQ(fdp.consume_integral<int16_t>(), static_cast<int16_t>(0x00FF));
}

TEST(FuzzedDataProvider, Int16Boundaries) {
  struct Case {
    std::array<uint8_t, 2> bytes;
    int16_t expected;
  };
  const std::array<Case, 4> cases{{
      {{0x00, 0x80}, std::numeric_limits<int16_t>::min()},  // -32768
      {{0xFF, 0x7F}, std::numeric_limits<int16_t>::max()},  //  32767
      {{0xFF, 0xFF}, int16_t{-1}},
      {{0x00, 0x00}, int16_t{0}},
  }};
  for (const auto& c : cases) {
    FuzzedDataProvider fdp(c.bytes.data(), c.bytes.size());
    EXPECT_EQ(fdp.consume_integral<int16_t>(), c.expected);
  }
}

TEST(FuzzedDataProvider, Deterministic) {
  const std::array<uint8_t, 5> bytes{0x01, 0x02, 0x03, 0x04, 0x05};
  FuzzedDataProvider a(bytes.data(), bytes.size());
  FuzzedDataProvider b(bytes.data(), bytes.size());
  EXPECT_EQ(a.consume_integral<int16_t>(), b.consume_integral<int16_t>());
  EXPECT_EQ(a.consume_integral<int16_t>(), b.consume_integral<int16_t>());
  EXPECT_EQ(a.consume_byte(), b.consume_byte());
}

TEST(FuzzedDataProvider, ConsumeByteAdvances) {
  const std::array<uint8_t, 3> bytes{0xAA, 0xBB, 0xCC};
  FuzzedDataProvider fdp(bytes.data(), bytes.size());
  EXPECT_EQ(fdp.remaining(), 3u);
  EXPECT_EQ(fdp.consume_byte(), 0xAA);
  EXPECT_EQ(fdp.remaining(), 2u);
}

// --- decode_pair ------------------------------------------------------------

TEST(DecodePair, ReadsTwoLittleEndianOperands) {
  // a = 0x0100 (256), b = 0x8000 (INT16_MIN)
  const std::array<uint8_t, 4> bytes{0x00, 0x01, 0x00, 0x80};
  FuzzedDataProvider fdp(bytes.data(), bytes.size());
  const auto pair = fuzz::decode_pair(fdp);
  EXPECT_EQ(pair.a, int16_t{256});
  EXPECT_EQ(pair.b, std::numeric_limits<int16_t>::min());
}

TEST(DecodePair, EmptyInputYieldsZeroZero) {
  FuzzedDataProvider fdp(nullptr, 0);
  const auto pair = fuzz::decode_pair(fdp);
  EXPECT_EQ(pair.a, int16_t{0});
  EXPECT_EQ(pair.b, int16_t{0});
}

// --- decode_op --------------------------------------------------------------

TEST(DecodeOp, MapsLowTwoBits) {
  const std::array<uint8_t, 4> bytes{0x00, 0x01, 0x02, 0x03};
  FuzzedDataProvider fdp(bytes.data(), bytes.size());
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Add);
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Subtract);
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Multiply);
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Divide);
}

TEST(DecodeOp, MasksHighBits) {
  // 0xFF & 0x03 == 0x03 == Divide; selector stays in range for any byte.
  const std::array<uint8_t, 2> bytes{0xFF, 0xFE};
  FuzzedDataProvider fdp(bytes.data(), bytes.size());
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Divide);
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Multiply);  // 0xFE & 0x03 == 0x02
}

TEST(DecodeOp, ExhaustedStreamSelectsAdd) {
  FuzzedDataProvider fdp(nullptr, 0);
  EXPECT_EQ(fuzz::decode_op(fdp), Op::Add);  // zero-fill -> 0 -> Add
}

}  // namespace
