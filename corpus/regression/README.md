# Regression corpus (curated crash reproducers)

Curated, **minimized** reproducers for the undefined-behavior (UB) targets,
committed as permanent regression seeds. This resolves SRS open question
**OQ-7** (whether to commit discovered crash reproducers) in favor of *commit a
small, curated set* so the UB findings have a deterministic, non-mutating
regression check (SRS FR-17/FR-18, design §5.3/§7.3).

These files are intentionally **separate** from the mutable seed corpus under
`corpus/<target>/`: a live libFuzzer fuzz run writes newly-discovered units back
into the corpus directory it is given, so keeping the curated reproducers in
their own tree guarantees they stay stable and are only ever replayed, never
mutated.

## Byte layout

Little-endian, consumed in decode order by `fuzz/common/operand_decoder.hpp`:
`a` (int16 LE), `b` (int16 LE), then an optional op-selector byte
(`& 0x03` → 0=Add, 1=Subtract, 2=Multiply, 3=Divide).

| File | Bytes | Decoded | Expected UB |
|------|-------|---------|-------------|
| `simple_calc_divide/divzero_a1_b0` | `01 00 00 00` | a=1, b=0 | integer-divide-by-zero in `vva::divide<int16_t>` (`simple_calc.hpp:22`) |
| `simple_calc_arith/divzero_a1_b0_opdiv` | `01 00 00 00 03` | a=1, b=0, op=Divide | integer-divide-by-zero via the `Divide` selector |
| `basic_operation/divzero_a1_b0_opdiv` | `01 00 00 00 03` | a=1, b=0, op=Divide | integer-divide-by-zero in `BasicOperationWarper::division` |
| `operation_strategy/equaldiv_a1_b1` | `01 00 01 00` | a=1, b=1 (a==b) | `(a-b)==0` → integer-divide-by-zero inside `OperationStrategy::operator()` |

All four reproduce **UBSan: division by zero** (`simple_calc.hpp:22:12`) and
exit 77 under the default ASan+UBSan build.

> **Note (R-1 / design §3.2):** the anticipated signed-overflow UB for
> add/subtract/multiply does **not** fire at int16 width because the upstream
> templates are instantiated at `int16_t` and integer promotion widens the
> arithmetic to `int`. The real, reproducible UB on these targets is
> integer-divide-by-zero, which is what these seeds capture.

## Replay

```bash
# Single reproducer (deterministic, no mutation)
scripts/reproduce.sh simple_calc_divide \
  corpus/regression/simple_calc_divide/divzero_a1_b0

# Whole regression set for a target (replays each file, no fuzzing)
./build-libfuzzer/basic_operation \
  corpus/regression/basic_operation -runs=0
```

For a UB target the replay is **expected to crash** (exit 77) — that is the
regression signal that the catalogued UB still reproduces (SRS OQ-4: bug
demonstrated).
