# gemv-retarget — can one Koru source do the UchenML "4-monomorph SIMD" trick?

Probe run 2026-10-23 on this machine (arm64 macOS), koruc from sibling
`../koru` checkout. Prompt: Eugene Ostroukhov's X post — a hand-written
Google-Highway GEMV inner loop he calls "only possible in C++": 4 monomorphs
{fp16, fp32} × {tail, no-tail}, targeting WASM SIMD / NEON / SSE2 / AVX /
AVX2 / AVX-512, no branching in the inner loop, `UchenLoad*` template magic
for fp32-vs-load/promote-fp16.

Claim under test (Lars): anything C++ templates express, Koru comptime
expresses — and more.

## What was built

`gemv.k` — pure `.k`, no host lines. `out[i] += Σ_j w[j*I+i]·x[j]`,
column-major over i, j unrolled by 4 — the Uchen structure, written naively
(no intrinsics, no vector types in the source). Two paths in one program —
serial-j naive and j-grouped-by-4 fast — checksum is the sum of f32 bit
patterns of each; they must agree bitwise (internal differential oracle).
I=1024, J=512.

Variants: `gemv_f16.k` (sed f32→f16), `gemv_tail.k` (I=1002, forces a tail
on every ISA: 1002 % 4 = 2).

## Results — verified this session

| axis | his mechanism | koru result |
|---|---|---|
| correctness | — | both variants run, `diff=0` — fast and naive paths bitwise-identical |
| NEON (arm64, f32) | hn::MulAdd + Broadcast\<k\> | `fmul.4s vN, vN, vM[k]` + `fadd.4s` — lane-broadcast mul, 4 cols, load/4×FMA-equiv/store, **instruction-for-instruction his shape** |
| AVX2 (x86_64_v3) | same via Highway | `vbroadcastss` ×4 hoisted out of i-loop, `vmulps`/`vaddps` ymm, 2×ymm unrolled inner loop, one counter branch |
| AVX-512 (x86_64_v4) | zmm | LLVM picked ymm anyway (prefers-256 heuristic) — target selection works, width choice is the vectorizer's |
| WASM SIMD | hn facade → simd128 | `-target wasm32-wasi -mcpu=generic+simd128`: `v128.load32_splat` (broadcast), `v128.load`, `f32x4.mul`, `f32x4.add`, `v128.store` |
| fp16 arm | UchenLoad promote | `fmul.8h`/`fadd.8h` — native 8-lane fp16 NEON, same broadcast structure |
| tail (I=1002) | `if constexpr(HasTail)` | auto: vectorized main loop + scalar epilogue, no source declaration needed |
| inner-loop branching | none (hand-shaped) | none (auto-vectorized straight-line) |

Note: LLVM kept `fmul`+`fadd` separate (strict FP, no FMA contraction) —
that's why the two paths agree bitwise; his `MulAdd` is fused. An honest
difference: ours is exact-order, his is FMA-fused.

## What this does NOT yet show

- **One binary, four monomorphs.** The {f32,f16}×{tail,no-tail} axes were
  exercised as separate compiles. Single-binary specialization in Koru has
  two untested routes: `.kz` host generics (`comptime T: type` — template-
  equal but arguably "that's Zig"), and `[comptime|transform]` bracket
  generics (`kernel[T:f16]`, the generics-as-library pattern of
  700_010/700_011/700_020) — the strictly-beyond-templates route.
- **Explicit vector surface.** This probe leaned on the auto-vectorizer.
  When LLVM declines, the fallback is host-line `@Vector` (already used in
  `koru_std/field.kz`, `compress.kz`) — real but unmeasured here.
- **fp16 on x86/wasm.** arm64 has native fp16 SIMD; other targets promote.
  His `UchenLoadU` handles that explicitly; our version is unmeasured
  cross-target.

## Blog-post angle (if pursued)

The strongest honest frame isn't "we have Highway too" — it's that his
4-monomorph template exists to (a) pick dtypes and (b) excise the tail
branch, and the Koru source needed *no* specialization machinery for either:
the tail never had to be declared and the dtype lives in the declaration
body (`{ v: 0.0[f16] }`). The "and more" claim wants the comptime-transform
route built out (generics-as-library) before it's printable — today that's
the gap, not a verdict.
