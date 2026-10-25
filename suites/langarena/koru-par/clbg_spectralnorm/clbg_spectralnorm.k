// clbg_spectralnorm — PARALLEL-CLASS variant of the serial koru/ port.
//
// Lane ruling (Lars, 2026-10-25): koru/ stays pure serial; koru-par/
// carries [parallel] variants as a separate honest track — NOT a
// LangArena submission (the arena's own reference is single-threaded;
// CLBG's published winners are multithreaded, which is a different
// class). The four outer row loops (rau/rav/rtv/rtu) are marked
// `[parallel]for` — rows are independent by construction; the only
// shared write is one std/grid:stored per row at a disjoint index,
// mutex-guarded by the dirty flood. Inner fold stays serial per row.
//
// Measured (arm64 dev box, hyperfine -N warmup 2 min-runs 8):
//   serial 820.7ms -> parallel 157ms = 5.22x, checksum-identical
//   (1052198219 == oracle). User 0.94s / real 0.155s ~ 6 real cores.
//   vs the board's rust_s 0.675s this would read ratio ~0.23 — a
//   DIFFERENT-CLASS number, not a serial-class win.
//
// Spelling note: `[parallel]` on the impl decl marks the head call —
// `[parallel]rau = for(0..1200)` IS the parallel loop. (Mid-chain
// `|> [parallel]for(...)` also works; both lanes land on the same
// `__parallel` template check.)

// clbg_spectralnorm — LangArena CLBG::Spectralnorm, run.js scored
// parameters (size=1200, iterations=132, warmup default
// iters*0.2 = 26 → 158 runs; u/v persist across runs — each run does
// v_new = AtA·u then u_new = AtA·v_new; checksum =
// checksumFloat(sqrt(vBv/vv)) — oracle 1052198219).
//
// A(i,j) = 1 / (s(s+1)/2 + i + 1), s = i+j — the CLBG spectral-norm
// power-iteration kernel. Pure f64 grids; the two-step AtA is staged
// through the gw scratch row, exact operation order as the
// reference's eval_A_times_u / eval_At_times_u pair.
//
// Optimizations and faithfulness diffs vs the original port:
//
// - CANONICAL FOR + CAPTURED ACCUMULATOR: the column loops are spelled
//   `capture { s } ! as a |> for(0..1200) ! each j |> captured { s: ... }`,
//   which lowers to a Zig `for (0..1200)` with a struct-field sum —
//   the shape whose LLVM emits the SAME partially-vectorized inner
//   loop the Rust reference's own binary carries: vector
//   add.2d/ucvtf.2d/fmul.2d/fdiv.2d computing 8 elements per
//   iteration, then 8 sequential scalar fadd's keeping the reduction
//   IN ORDER (disasm receipts /tmp/sn_disasm_*.txt; ~55 instrs/8
//   elements vs Rust's ~52). The original spelled the loops as tor
//   self-calls accumulating through the fs.sum store row inside a
//   `while(true)` — correct but entirely scalar.
// - SLICE BORROWS (recipe 2): gu_s/gv_s/gw_s borrow the f64 columns;
//   inner reads are raw index, no __koru_at floor per element.
// - GSRC STAGING REMOVED: the original copied gu/gv into a gsrc row so
//   one column tor could serve both passes. Per-source inner loops
//   make the copies pure traffic — same reads, same values,
//   bit-identical. Two 1200-element copies per run deleted.
// - Denominator evaluated per element exactly as the reference does
//   (f64 s*(s+1)/2 + row + 1, 1.0/denom first, then *src[j]); the sum
//   order is unchanged — one in-order fadd per element, no
//   reassociation, no extra accumulators.
//
// MEASUREMENT-BASIS FINDING (wave-4): the benchmark's "Rust 0.689s"
// is the harness's measured-iterations number — 132 runs, warmup
// EXCLUDED. The Koru whole-process number covers all 158 runs. On the
// identical basis (whole-process, min-of-5 interleaved):
//   Rust 0.81-0.83 / this kernel 0.80-0.83 / original port 0.80-0.83
// — all three tie. The kernel is bound by the serial in-order fadd
//   chain (~0.88ns/elem ~= 4cyc x 910M elems ~= 0.80s), a floor no
//   legal rewrite can cross: reassociating the reduction would change
//   the checksum. A 132-run probe build (/tmp/sn_k132) matches Rust's
//   measured-only basis at 0.68s vs its 0.689-0.702s.
//
// Falsified on this kernel (kept for the map):
// - Param-carried d/t incremental denominator (d += t, i64, exact —
//   verified bit-identical for all 1200x1200 via /tmp/sn_dcheck.py)
//   inside the tor self-loop shape: checksum green, ~0.81s — correct
//   but not faster; the denominator math was never the constraint.
// - Vectorized fdiv.2d as a TIME lever: emitted, verified, and still
//   ~0.80s — off-chain throughput hides under the fadd chain; kept
//   anyway because it is the minimal-pressure shape.
// - The original port was ALREADY at the floor: its 0.82s covered 158
//   runs. There was no kernel deficit; the gap was accounting.

import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(gu, size: 1200) { v: 0.0[f64] }
std/grid:new(gv, size: 1200) { v: 0.0[f64] }
std/grid:new(gw, size: 1200) { v: 0.0[f64] }
std/store:new(st) { t3: 0[i64] }
std/store:new(fs) { vbv: 0.0[f64], vv: 0.0[f64] }

std/grid:slice(gu_s) { gu.v }
std/grid:slice(gv_s) { gv.v }
std/grid:slice(gw_s) { gw.v }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// ---- eval_A_times_u: out[i] = sum_j A(i,j)*src[j] ----
// rau: gw = A·gu ; rav: gw = A·gv

pub tor rau { } -> i64
[parallel]rau = for(0..1200)
    ! each i |> capture { s: 0.0[f64] }
        ! as a |> for(0..1200)
            ! each j |> captured { s: a.s + 1.0 / ((@as(f64, @floatFromInt(i)) + @as(f64, @floatFromInt(j))) * (@as(f64, @floatFromInt(i)) + @as(f64, @floatFromInt(j)) + 1.0) / 2.0 + @as(f64, @floatFromInt(i)) + 1.0) * gu_s[j] }
        | captured r |> std/grid:stored { gw_s[i]: r.s }
    | done |> ret0(): _ -> 0

pub tor rav { } -> i64
[parallel]rav = for(0..1200)
    ! each i |> capture { s: 0.0[f64] }
        ! as a |> for(0..1200)
            ! each j |> captured { s: a.s + 1.0 / ((@as(f64, @floatFromInt(i)) + @as(f64, @floatFromInt(j))) * (@as(f64, @floatFromInt(i)) + @as(f64, @floatFromInt(j)) + 1.0) / 2.0 + @as(f64, @floatFromInt(i)) + 1.0) * gv_s[j] }
        | captured r |> std/grid:stored { gw_s[i]: r.s }
    | done |> ret0(): _ -> 0

// ---- eval_At_times_u: out[i] = sum_j A(j,i)*gw[j] ----
// rtv: gv = At·gw ; rtu: gu = At·gw — denominator's +row+1 term
// follows j (the A row index), i.e. eval_a(j, i) as the reference.

pub tor rtv { } -> i64
[parallel]rtv = for(0..1200)
    ! each i |> capture { s: 0.0[f64] }
        ! as a |> for(0..1200)
            ! each j |> captured { s: a.s + 1.0 / ((@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i))) * (@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i)) + 1.0) / 2.0 + @as(f64, @floatFromInt(j)) + 1.0) * gw_s[j] }
        | captured r |> std/grid:stored { gv_s[i]: r.s }
    | done |> ret0(): _ -> 0

pub tor rtu { } -> i64
[parallel]rtu = for(0..1200)
    ! each i |> capture { s: 0.0[f64] }
        ! as a |> for(0..1200)
            ! each j |> captured { s: a.s + 1.0 / ((@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i))) * (@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i)) + 1.0) / 2.0 + @as(f64, @floatFromInt(j)) + 1.0) * gw_s[j] }
        | captured r |> std/grid:stored { gu_s[i]: r.s }
    | done |> ret0(): _ -> 0

// onerun — v_new = AtA·u then u_new = AtA·v_new
pub tor onerun { } -> i64
onerun = rau(): _
    |> rtv(): _
    |> rav(): _
    |> rtu(): _
    |> ret0(): _ -> 0

// runl — 158 runs (132 measured + 26 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 158)
| then |> onerun(): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- checksum: sqrt(vBv / vv) → checksumFloat ----

pub tor dotl { i: i64, vbv: f64, vv: f64 } -> i64
dotl = if(i < 1200)
| then |> dotl(i: i + 1, vbv: vbv + gu_s[@as(usize, @intCast(i))] * gv_s[@as(usize, @intCast(i))], vv: vv + gv_s[@as(usize, @intCast(i))] * gv_s[@as(usize, @intCast(i))]): r -> r
| else |> std/store:stored { fs.vbv: vbv, fs.vv: vv }
    |> ret0(): _ -> 0

// djh — DJB2 a scoped string into st.t3 (u32 arithmetic)
pub tor djh { t: string<*@scoped> } -> i64
djh = for(0..t.len)
    ! each k |> std/store:stored { st.t3: @rem(st.t3 * 33 + @as(i64, @intCast(t[k])), 4294967296) }
    | done
    |> ret0(): _ -> 0

pub tor csfv { v: f64 } -> i64
csfv = std/fmt:ln("{{ v:d:.7 }}"): s
    |> std/store:stored { st.t3: 5381 }
    |> djh(t: s.text): _
    |> ret0(): _ -> st.t3

// ---- driver ----

// u = v = 1.0
for(0..1200)
! each i |> std/grid:stored { gu_s[i]: 1.0 }
    |> std/grid:stored { gv_s[i]: 1.0 }

runl(k: 0): _
|> dotl(i: 0, vbv: 0.0, vv: 0.0): _
|> csfv(v: @sqrt(fs.vbv / fs.vv)): h
|> std/io:print.ln("{{ h:d }}")
