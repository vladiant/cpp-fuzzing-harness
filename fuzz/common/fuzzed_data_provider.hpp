#ifndef FUZZ_COMMON_FUZZED_DATA_PROVIDER_HPP
#define FUZZ_COMMON_FUZZED_DATA_PROVIDER_HPP

/// \file fuzzed_data_provider.hpp
/// \brief Minimal, header-only, non-owning cursor over the fuzzer-provided
///        byte buffer.
///
/// This is intentionally a ~40-line reimplementation rather than a dependency on
/// LLVM's compiler-shipped `FuzzedDataProvider.h`: it is portable across
/// clang-18 / afl-clang-fast++, drags in no toolchain-specific header path, and
/// — crucially — is unit-testable in isolation (it is the only logic this repo
/// owns). See design §3.2.
///
/// Contract (unit-tested in tests/test_operand_decoder.cpp):
///   1. Never reads out of bounds; returns deterministic 0-fill on exhaustion.
///   2. Decoding is pure and stable: identical bytes -> identical values.
///   3. No allocation, no recursion, no input-controlled loop bounds (NFR-6).

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <type_traits>

namespace fuzz {

/// Non-owning view over `[data, data + size)`. Value type; performs no heap
/// allocation and never takes ownership of the buffer.
class FuzzedDataProvider {
 public:
  FuzzedDataProvider(const uint8_t* data, size_t size) noexcept
      : cursor_(data), end_(data + size) {
    // Guard against a null pointer with non-zero size defensively collapsing to
    // an empty range (callers should never do this, but we must not deref null).
    if (data == nullptr) {
      cursor_ = nullptr;
      end_ = nullptr;
    }
  }

  /// Consumes `sizeof(T)` bytes little-endian and returns the decoded integer.
  /// Missing bytes (buffer exhausted) are treated as zero. Never reads OOB,
  /// never throws. `T` must be an integral type.
  template <class T>
  T consume_integral() noexcept {
    static_assert(std::is_integral<T>::value,
                  "consume_integral<T>() requires an integral T");
    using U = typename std::make_unsigned<T>::type;
    U result = 0;
    for (size_t i = 0; i < sizeof(T); ++i) {
      const U byte = (cursor_ < end_) ? static_cast<U>(*cursor_++) : U{0};
      result = static_cast<U>(result | (byte << (8 * i)));
    }
    T out;
    std::memcpy(&out, &result, sizeof(T));
    return out;
  }

  /// Consumes a single byte, or 0 when the buffer is exhausted.
  uint8_t consume_byte() noexcept {
    return (cursor_ < end_) ? *cursor_++ : uint8_t{0};
  }

  /// Number of unconsumed bytes remaining.
  size_t remaining() const noexcept {
    return static_cast<size_t>(end_ - cursor_);
  }

 private:
  const uint8_t* cursor_;
  const uint8_t* end_;
};

}  // namespace fuzz

#endif  // FUZZ_COMMON_FUZZED_DATA_PROVIDER_HPP
