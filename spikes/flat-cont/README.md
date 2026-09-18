# flat-cont — BendRT-shaped flat continuation backend, hand-rolled prototype

Measured 2026-09-18, M2 Pro, zig 0.15.2, `-O ReleaseFast`, `hyperfine -N --warmup 3 --min-runs 10`.

Hand-written minimal version of Bend 2's generated runtime shape, applied to
the osprey-compute-kernels tree-recursion workloads:

- every "function" is a **segment**: `fn (sp, r0..r2) u64`, uniform signature
- calls are `@call(.always_tail, ...)` jumps — no C/Zig stack growth
- non-tail calls push a **continuation lane** `{fid, w0..w3}` on an explicit
  stack; a return pops the lane and tail-calls its `fid` with the result in `r0`
- `fDone` is the bottom continuation that unwinds the whole chain to `main`

## Results vs the board (`suites/osprey-compute-kernels`)

| kernel | flat (this spike) | koru | c | bend | bend-par |
|---|---:|---:|---:|---:|---:|
| ackermann | **27.7** | 145.8 | 135.1 | 65.2 | — |
| tak | **3.8** | 45.5 | 44.0 | 140.3 | 52.8 |
| hanoi | **51.5** | 70.3 | 70.7 | 111.7 | — |
| fib | 34.2 | **28.3** | 28.2 | 111.7 | 31.7 |

Work verified identical: flat tak executes 2,493,349 segment entries, same as
counted plain-C recursion (`count.c`/`count2.zig` in the session, not kept).

## What bites

- **A continuation must consume its own lane.** Calling the next segment with
  `sp + 1` leaves the lane on the stack; the callee's pop re-runs the dead
  continuation forever. Call with `sp` after reading the lane's words.
- **The register file is caller-clobbered.** Anything needed after a call must
  live in the lane, not in r0–r2 (first tak draft carried `z` in `r2` → wrong
  answer, 8 vs 9).
- Zig `.always_tail` requires caller and callee signatures to match — which is
  exactly the uniform-segment ABI, so it costs nothing.
- The win is depth-dependent: long continuation chains (ackermann ~5×, tak ~12×,
  hanoi ~1.35×) win big; shallow tree recursion (fib) is slightly *behind* the
  native stack. This is a selectable emission shape, not a replacement.

## Files

- `flat.zig` — ackermann(3,10) → 8189
- `flat2.zig` — fib(35) → 9227465, hanoi(25) → 33554431
- `flat3.zig` — tak(24,16,8) → 9
- `flat.c` — the C/clang `preserve_none` + `musttail` version (ack, hanoi)

Build: `zig build-exe flatN.zig -O ReleaseFast -femit-bin=flatN`
