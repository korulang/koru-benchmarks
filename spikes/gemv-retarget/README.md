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

## The comptime-transform route — `generic/gemv.kz` (verified 2026-10-23)

`generic/gemv.kz` closes the "one binary, four monomorphs" gap via the
generics-as-library pattern: a `~[comptime|transform] pub tor gemv.*` +
`~proc gemv.*|zig` handler parses bracket params at compile time and
*writes the program* — each invocation is replaced by a specialized set of
Zig decls (storage + init + fast kernel + naive oracle + report):

```
~gemv.kernel[T:f32;I:1024;J:512](name: "k_f32")   // no tail
~gemv.kernel[T:f32;I:1002;J:512](name: "k_f32t")  // tail (1002 % 4 = 2)
~gemv.kernel[T:f16;I:1024;J:512](name: "k_f16")   // fp16
~gemv.kernel[T:f16;I:1002;J:512](name: "k_f16t")  // fp16 + tail
```

Verified: `koruc build gemv.kz` → one `a.out` containing all four
monomorphs; `output_emitted.zig` shows four concrete decl-sets
(`k_f32_w: [524288]f32`, `k_f16_w: [524288]f16`, …). Runtime:

```
k_f32  [T=f32 I=1024 J=512]: fast=1962631888896 naive=1962631888896 diff=0
k_f32t [T=f32 I=1002 J=512]: fast=1922704277504 naive=1922704277504 diff=0
k_f16  [T=f16 I=1024 J=512]: fast=25571280     naive=25571280     diff=0
k_f16t [T=f16 I=1002 J=512]: fast=25055448     naive=25055448     diff=0
```

Cross-target disassembly of the generated kernels (ReleaseFast):

| target | emitted |
|---|---|
| arm64 NEON | `fmul.4s v5,v5,v0[0]` + `fadd.4s` — 4 broadcast-mul chains (also 4× unrolled i in places); f16 monomorphs: `fmul.8h`/`fadd.8h` |
| x86_64 AVX2 (v3) | `vbroadcastss` + `vmulps`/`vaddps` ymm (230 vector fp ops total) |
| x86_64 AVX-512 (v4) | 368 zmm + 1023 ymm — v4 actually uses zmm here |
| wasm32+simd128 | `v128.load32_splat`, `f32x4.mul`, `f32x4.add`, `f32x4.splat`; f16 monomorphs scalarize to `f32.mul`/`f32.add` (wasm has no fp16 type) |

This is the "and more": the transform isn't a template stamp — it reads the
invocation site's bracket params and synthesizes a program artifact
(typed storage, unrolled kernel, differential oracle, report fn) that never
existed in source. C++ `if constexpr` chooses between arms the programmer
wrote; this writes the arms.

## Gotchas discovered (worth a pin)

- `~[transform] proc` ≠ `~proc`: the `[transform]` annotation routes the
  event through `emitTransformProcEventStruct` which emits a FIXED
  machine-ABI Input `{invocation,item,program,allocator,reporter}` —
  `event_name` is dropped from Input while the callsite still writes it
  → "no field named 'event_name'". Declaring a plain `~proc gemv.*|zig`
  takes the input_shape path where `event_name: string` is honored
  (700_011 shape). Possible compiler wart: the machine-ABI Input omits
  `event_name` even though the dispatcher can pass it.
- `SiteResult` is returned directly on the input_shape path —
  `.{ .replacement = item }`, not `.{ .transformed = ... }`.
- `std.fmt.allocPrint` caps at 32 args — split large templates.

## What this does NOT yet show

- **Explicit vector surface.** This probe leaned on the auto-vectorizer.
  When LLVM declines, the fallback is host-line `@Vector` (already used in
  `koru_std/field.kz`, `compress.kz`) — real but unmeasured here.
- **fp16 on x86/wasm.** arm64 has native fp16 SIMD; wasm scalarizes (no
  fp16 ops at all in the spec). His `UchenLoadU` handles promote-on-load
  explicitly; ours delegates to the backend.

## Blog-post angle (if pursued)

The honest frame: his 4-monomorph template exists to (a) pick dtypes and
(b) excise the tail branch. The plain `.k` source needed no specialization
machinery for either. And the "and more" is now concrete, not asserted:
`generic/gemv.kz` shows a comptime transform that reads bracket params and
*generates the specialized program* — storage, kernel, oracle — something
no template mechanism can express. Link back to the X post; show
`output_emitted.zig` and the disassembly, not benchmarks — no perf claim
against Uchen is being made (different workload; langguess end-to-end
remains unmeasured).

## Grammar note: glob paths, brackets, and the `[*]` ruling (2026-10-23)

Probing the dispatch grammar around the generic transform produced a full
truth table (all four rows compiled/refused this session):

| declared tor | invocation | result |
|---|---|---|
| `gemv.kernel` | `gemv.kernel[T:…]` | refuse — `KORU040 unknown tor 'gemv.kernel[T:…]'`: the bracket text is glued INTO the path segment, so the exact name can never match a parameterized call |
| `gemv.kernel*` | anything | refuse — `PARSE003`: `*` must be a whole `.`-separated piece; it is a segment wildcard, NOT a string-suffix glob |
| `gemv.*` | `gemv.kernel[T:…]` | accept — `*` matches the `kernel[T:…]` piece whole |
| `gemv.kernel.*` | `gemv.kernel.*[T:…]` | accept — literal `*` spelled in BOTH declaration and call site |

Two findings: a glob is mandatory for bracketed dispatch (no exact tor can
match), and the literal-star invocation `gemv.kernel.*[T]` is an emergent
spelling — works end to end, absent from the pinned tests.

**Ruling (Lars):** the parameter marker belongs in the parameter channel.
Desired surface is `tor gemv.kernel[*]` + invocation `gemv.kernel[T:…]` —
`[*]` is a single opaque marker meaning "this name admits a bracket tail,"
NOT a bracket grammar. The bracket content stays an opaque string the
transform proc parses itself (what `gemv.kz`'s proc already does with
`event_name` today); conventional shapes (`k:v;` lists) can later ship as
stdlib helpers linked into the backend compiler. `.*` stays pure
namespace globbing (`log.*`, `ring.*`); `gemv.kernel[*]` keeps
parameterization bracket-local so the two mechanisms stay orthogonal.
IMPLEMENTED 2026-10-23 (koru main.zig + visitor_emitter.zig): needed
zero grammar changes — the parser already accepted bracket tails on decl
names and matchSegment's middle-wildcard rule already matched `kernel[*]`
→ `kernel[T:…]`; the only break was Zig-ident mangling (`gemv_kernel[_star_]`
— `[`/`]` passed through raw). Escape convention extended to `[ ] : ! ; , =`
in both manglers. Pins: regression 700_012 (accept) + 700_013 (bare
`ring.new` vs `ring.new[*]` → KORU040). `generic/gemv.kz` now uses the
canonical `gemv.kernel[*]` surface; four monomorphs still diff=0.
