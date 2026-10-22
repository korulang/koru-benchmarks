# High-performance Koru — the measured recipes

Every recipe below was discovered on the goose-race board (matmul, primes,
brainfuck, base64, json vs Goose — all at or ahead) by **compiling probes and
counting instructions on the emitted asm**, not by reasoning about source
shape. That is the method, stated once, up front:

> **The vectorizer checks the emitted shape, not the structure.** The call
> architecture you see in `.k` — handlers, write units, `_ = &x` keepalives —
> is free (LLVM inlines through all of it). What decides speed is invisible
> at that level: lane width, merge arity, read/write paths. Bisect on
> `output_emitted.zig` and a minimal replica; the per-iteration instruction
> count on `objdump -d` is the only verdict. Intuition about "simple" vs
> "complex" source falsified four hypotheses on the way here.
> — `concepts/frag-the-vectorizer-checks-the-emitted-shape-not-the-structure`

The verification discipline is not optional: **correctness first, always** —
the checksum/`expected.txt` oracle must pass before any timing is spoken of;
then min-of-N interleaved runs; then instructions retired. A faster wrong
program is a lie, not a win.

## The recipes

### 1. Lane width is a type decision
Vector lane count = 128 bits / element width. `i64` fields → 2-wide lanes or
scalar fallback; `u8` → 16-wide. Narrow every field that can be: index-like
columns to `u32`/`0[grid]`, flags/tags to `u8`. `0[grid]` (certified index)
stores the narrowest uint for the extent, moves the bounds check to the
*write*, and reads raw. `primes` went from behind to ahead on field widths
alone; `matmul`/`base64` needed u8 arithmetic to reach 16-wide lanes.

### 2. Borrowed windows over floored reads
Per-cell `grid[i].f` reads re-check the floor every access. `std/grid:slice`
borrows a column window; `std/grid:walk { s: g.c, n, d: h.c, m }` reslices a
moving window — the shape LLVM turns into `ld3`/`st3`/`ld4`/`st4` interleaved
vector loads/stores. If a kernel indexes a grid in a hot loop, the first
question is whether a walk window exists for the access pattern.

### 3. Bound two-way ifs — the select recipe
Multi-way value dispatch (map a byte/int to one of N results):

```k
pub tor idv8 { v: u8 } -> u8
idv8 -> v

value = idv8(v: if (c == 47) @as(u8, 63) else 255): r4
    |> idv8(v: if (c == 43) @as(u8, 62) else r4): r3
    |> idv8(v: if (c >= 48 and c < 58) c +% 4 else r3): r2
    |> idv8(v: if (c >= 97 and c < 123) c -% 71 else r2): r -> r
```

Each `|>` binds `const r = if (c) x else acc` — a clean 2-predecessor
diamond, which SimplifyCFG folds to a `select`; the chain lowers to NEON
`bit`/`bsl` (~8 ops/value, matching clang's ternary-cascade codegen).
`cond`'s early-return cascade and `if/else-if` expression ladders emit
*multi*-predecessor merges — SimplifyCFG can't fold them, they stay branchy,
and the vectorizer declines. Base64 encode: 171→116ms on this alone.

### 4. `std/switch:char` for sparse dispatch
Emits a real Zig `switch` — a compare tree on sparse values. A dense
re-encoding to force a jump table was *slower* (falsified: the compare tree
wins when the hot op mix is few). Use it for byte-op dispatch
(brainfuck's op dispatch).

### 5. Wrapping arithmetic for byte lanes
`+%`, `-%`, `*%` spell Zig wrapping ops — the only way to do u8 lane math
(`v0*%4 +% v1/16` for `a<<2 | b>>4`). A `u32` pack (`u16` widen + `@divTrunc`
+ `@rem`) costs 4-wide lanes where u8 runs 16-wide — base64 decode went
308→201ms on this. `-%` does NOT parse inside `when` guards (falsified).

### 6. Tail-call self-loops carry registers
A tor's self-call with loop state as *parameters* emits
`continue :__koru_self_loop` — `ip`/`pos`/cursor state stays register-resident,
no memory round-trip. Per-op handler indirection (`nip`-style) is pure
overhead: each advance was a real call + re-entry; direct self-calls removed
it. Loop state in a `std/store` row is memory-resident by default — LLVM may
promote it, but params are the honest spelling.

### 7. Parse-time representation tricks are legal (disclose them)
Semantics-preserving peepholes at parse/emit time are the same genre as the
references' own representation tricks — brainfuck's `++++`→`INC(n)` run-fold
took the task 1.07×-behind → 0.55×-ahead. The rule: it must be exact
(checksum-identical on every input), and it must be disclosed in the kernel
header — never hidden.

### 8. The deficit may live in the input path, not the kernel
`parseFloat` wasn't json's bottleneck; `io:read-file`'s `readToEndAlloc`
was — 3 geometric copies of a 115MB file = 443MB peak RSS and most of the
row's time. Stat + one alloc + one `readAll` put it at parity (128MB).
Profile the *whole* pipeline before optimizing the hot stage.
— `concepts/frag-a-deficit-attributed-to-the-kernel-can-live-in-the-input-path`

### 9. Liveness vs dead stores — keep the work honest
Flat grids let LLVM elide store-only loops entirely (you'd benchmark
nothing). Keep stores live with a *real* consumed read per iteration —
`st.probe + @as(i64, dec[it*16127 % 131072].b)` — and run the full
byte-exact verify once after the loop when iterations are deterministic.
`st.probe - st.probe` folds to zero — LLVM sees through tricks; the read
must reach output.

### 10. Phase timing before whole-program timing
Print per-phase ms deltas (`std/time:now`) so "the 10% gap" becomes
"encode is 18% behind, decode 5%, overhead nothing" — three different
problems, three different fixes. Whole-process numbers hide where the
work actually is.

### 11. Computable positions → grid, not `std/store:insert`
`binarytrees_arena` paid `std/store:insert`'s per-row machinery ~75M
times (0.99s). The reference's push-order arena positions were DFS
preorder indexes — pure arithmetic (`left = h+1`, `right = h + 2^depth`)
— so a `std/grid` at the reference's exact row layout replaced the store
entirely: 0.99s → 0.11s (3.52× behind Rust → 0.39× ahead). Rules: every
grid slot is live (no fake-free pool — that would be a store wearing a
grid's name), positions must be *computable* not sequential-with-state,
and order-independent aggregates (`sum`) scan linearly instead of
pointer-chasing. Disclose the replacement in the kernel header and diff
the disasm to prove the field stores survived — LLVM DSE is the
falsifier that would make the win dishonest.

## The falsified list — hypotheses that cost runs

- **`while`→counted `for` driver**: honest (the trip count is real) but
  changed nothing — LLVM still won't unroll a reslice-carrying loop. Kept
  for contract clarity, not speed.
- **Manual 2× loop unroll**: destroyed vectorization (1714ms vs 46ms).
- **Nested if-expression produce**: scalar collapse (1373ms) — multi-pred
  merges don't fold (recipe 3 explains why).
- **`inline` on the handler**: not the blocker — the emitted shape was.
- **Jump-table re-encoding**: slower than the sparse compare tree.
- **`pool-alloc` per iteration**: mmap per call — far too expensive.
- **Pure-expression `value` via `*%`-scaling**: 5.0G vs 4.4G — worse than
  the cond cascade it replaced (pre-recipe-3).
- **`idv` binds that LLVM folds away**: `st.probe - st.probe` — dead.

## The loop of attack, per deficit

1. Reproduce + verify the oracle (`expected.txt`/checksum, `bad=0`).
2. Phase-time or profile — locate the cost (kernel? input path? verify?).
3. `objdump -d` both sides — count loop instructions, find the delta shape.
4. One hypothesis → one probe (emitted-file patch or minimal replica) →
   one measurement. Record falsified hypotheses — they are the map.
5. A retained change must be semantically honest AND measured: checksum
   green, min-of-3 improvement, no dead-code tricks.
6. `.k` where possible; `.kz` when the emitted host shape is the point —
   say so in the kernel header.
