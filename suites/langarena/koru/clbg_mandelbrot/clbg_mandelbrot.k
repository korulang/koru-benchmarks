// clbg_mandelbrot — LangArena CLBG::Mandelbrot, run.js scored
// parameters (w=400, h=400, iterations=100, warmup=20 → 120 runs;
// each run APPENDS "P4\n400 400\n" + 20000 bitmap bytes to result_bin
// — the buffer accumulates, 2401320 bytes total; checksum =
// checksumBytes over all of it — oracle 3455988829).
//
// RESULT: 1.12s → 0.12s whole-process min-of-5 (vs Rust 0.931s
// warmup-excluded internal window — koru's number carries the
// 120-run whole-process handicap). Checksum verified 3455988829.
//
// FAITHFULNESS — what differs from the reference's literal spelling:
//
// 1. esc8: the escape iteration runs 8 pixels (one output byte) in
//    lockstep instead of one pixel per loop. LLVM SLP packs the 8
//    lanes into NEON .2d pairs; independent chains also fill the
//    latency-bound FP pipeline. Semantics: lanes update
//    simultaneously from old state, exactly the reference's
//    z' = z² + c per pixel. A lane whose orbit escapes keeps
//    iterating beside live lanes: once |z| > 2 the orbit diverges
//    monotonically (|c| <= ~1.803 < 2 over this domain), so its
//    bound-sum stays > 4 — or overflows to inf/NaN, which also
//    fails <= 4 — so its bit evaluated at group exit equals the
//    reference's bit evaluated at its own exit. The group exits
//    when i == 50 or ALL lanes are dead; bit_j = (s_j <= 4) at
//    exit == reference's bit. Byte is MSB-first (lane0 = bit7),
//    matching byte_acc's shift-in order.
// 2. ph cadence: the all-dead check is evaluated only every 4th
//    state (ph cycles 0..3, check at ph==3 → s_3, s_7, s_11, ...).
//    Skipped checks only over-iterate dead lanes by <= 3 — same
//    monotonic-escape argument — bits unchanged. Measured: checks
//    every iter ~35% of loop cost; every-4th is the sweet spot.
// 3. inp/allin: period-1 cardioid + period-2 bulb membership,
//    closed form — members never escape in 50 iterations, so an
//    all-interior byte is 0xFF without running the orbit loop.
//    Exact math (interior ⊆ M ⊆ bounded orbits); the only hazard
//    is an FP-boundary misclassification, which the checksum
//    oracle verifies absent on this fixed 400x400 input.
//    ~33% of all bytes take this path (6528 of 20000 per run).
// 4. ti row gate: |ci| > 0.66 rows skip the interior test —
//    exact prefilter: the cardioid needs |ci| <= ~0.65 and the
//    bulb |ci| <= 0.25, so inp is provably 0 outside the gate.
// 5. crt: cr(x) = 2x/400 - 1.5 is a pure function of x — tabulated
//    once into a 400-cell f64 grid (same expression, same values)
//    instead of recomputed per pixel per row per run.
// 6. The per-pixel byte_acc/bit_num shift-accumulator is gone:
//    one byte is emitted per 8-pixel group. The reference's
//    w%8 pad branch is carried as dead — w=400 is a multiple of 8
//    so every group is a full byte and no padding ever fires.
// 7. doc writes + checksum reads go through slice splices (ds/crs):
//    the borrow contract moves the bounds obligation to the
//    program — st.p only reaches 2401320 < 2402000 and x+7 <= 399.
//    Checksum: (t3*33 + b) & 0xFFFFFFFF — t3 stays nonneg so the
//    mask is exactly @rem(_, 2^32) (u32 store leaves don't exist).
// 8. Falsified hypotheses (measured, rejected):
//    - unconditional-iteration prefix K>=4: dead groups' extra
//      iters cost more than the saved checks; K=2 ~+0.01 only.
//    - vector flag-sum check every iter (a0+..+a7>0, fcmge/umaxv):
//      0.23s vs 0.12s — i64 flag serialization every iteration
//      loses to the fccmp or-chain on a 4-tick cadence.
//    - check cadence every 6th/8th: dead-group over-iteration
//      exceeds saved check work.
//    - cr-bbox prefilter inside gated rows: guard fdivs cost more
//      than the skipped allin tests.
//    - lane-level interior flags for mixed bytes: only 608/20000
//      bytes are mixed and they save ~115 iters/run — not worth it.
//    - run-level memoization (all 120 runs emit identical bytes):
//      correct but skips the measured computation — not done.

import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(doc, size: 2402000) { b: 0[u8] }
std/grid:slice(ds) { doc.b }
std/grid:new(crt, size: 400) { v: 0.0[f64] }
std/grid:slice(crs) { crt.v }
std/store:new(st) { p: 0[i64], t3: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// crinit — cr(x) is a pure function of x; tabulate once
pub tor crinit { i: i64 } -> i64
crinit = if(i < 400)
| then |> std/grid:stored { crt[i].v: 2.0 * @as(f64, @floatFromInt(i)) / 400.0 - 1.5 }
    |> crinit(i: i + 1): r -> r
| else -> 0

// lit — copy a literal's bytes into the doc
pub tor lit { t: string } -> i64
lit = for(0..t.len)
    ! each k |> std/grid:stored { ds[@as(usize, @intCast(st.p))]: t[k] }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): _ -> 0

// pb — one raw byte
pub tor pb { b: i64 } -> i64
pb = std/grid:stored { ds[@as(usize, @intCast(st.p))]: @as(u8, @intCast(b)) }
    |> std/store:stored { st.p: st.p + 1 }
    |> ret0(): _ -> 0

// inp — period-1 cardioid + period-2 bulb membership (closed form).
// Members never escape in 50 iters -> bit 1. Exact math; FP
// boundary cases verified by checksum on this input.
pub tor inp { cr: f64, ci: f64 } -> i64
inp = if(((cr - 0.25) * (cr - 0.25) + ci * ci) * ((cr - 0.25) * (cr - 0.25) + ci * ci + cr - 0.25) <= 0.25 * ci * ci or ((cr + 1.0) * (cr + 1.0) + ci * ci) <= 0.0625)
| then -> 1
| else -> 0

// allin — 1 when all 8 lanes of the byte are set-interior
pub tor allin { cr0: f64, cr1: f64, cr2: f64, cr3: f64,
    cr4: f64, cr5: f64, cr6: f64, cr7: f64, ci: f64 } -> i64
allin = inp(cr: cr0, ci): a0
    |> inp(cr: cr1, ci): a1
    |> inp(cr: cr2, ci): a2
    |> inp(cr: cr3, ci): a3
    |> inp(cr: cr4, ci): a4
    |> inp(cr: cr5, ci): a5
    |> inp(cr: cr6, ci): a6
    |> inp(cr: cr7, ci): a7
    |> if(a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 == 8)
    | then -> 1
    | else -> 0

// b8 — pack 8 lane bound-sums into one byte (lane0 = MSB)
pub tor b8 { s0: f64, s1: f64, s2: f64, s3: f64, s4: f64, s5: f64, s6: f64, s7: f64 } -> i64
b8 = idv(v: if (s0 <= 4.0) @as(i64, 128) else 0): a0
    |> idv(v: if (s1 <= 4.0) a0 + 64 else a0): a1
    |> idv(v: if (s2 <= 4.0) a1 + 32 else a1): a2
    |> idv(v: if (s3 <= 4.0) a2 + 16 else a2): a3
    |> idv(v: if (s4 <= 4.0) a3 + 8 else a3): a4
    |> idv(v: if (s5 <= 4.0) a4 + 4 else a4): a5
    |> idv(v: if (s6 <= 4.0) a5 + 2 else a5): a6
    |> idv(v: if (s7 <= 4.0) a6 + 1 else a6): r -> r

// esc8 — escape loop over 8 lanes in lockstep. All lanes share ci;
// lanes update simultaneously from old state. A lane that escapes
// keeps iterating: once |z|>2 the orbit diverges monotonically
// (|c|<2 in this domain), so its sum stays >4 — or goes inf/NaN,
// which also fails <=4 — so its bit at group exit is unchanged.
// All-dead check runs only at ph==3 (every 4th state); skipped
// checks only over-iterate dead lanes, which is invisible.
// Group exits when i==50 or ALL lanes escaped; bit_j = s_j <= 4.
pub tor esc8 { i: i64, ph: i64, ci: f64,
    cr0: f64, cr1: f64, cr2: f64, cr3: f64,
    cr4: f64, cr5: f64, cr6: f64, cr7: f64,
    zr0: f64, zi0: f64, zr1: f64, zi1: f64,
    zr2: f64, zi2: f64, zr3: f64, zi3: f64,
    zr4: f64, zi4: f64, zr5: f64, zi5: f64,
    zr6: f64, zi6: f64, zr7: f64, zi7: f64 } -> i64
esc8 = if(i < 50 and (ph < 3 or zr0 * zr0 + zi0 * zi0 <= 4.0
        or zr1 * zr1 + zi1 * zi1 <= 4.0
        or zr2 * zr2 + zi2 * zi2 <= 4.0
        or zr3 * zr3 + zi3 * zi3 <= 4.0
        or zr4 * zr4 + zi4 * zi4 <= 4.0
        or zr5 * zr5 + zi5 * zi5 <= 4.0
        or zr6 * zr6 + zi6 * zi6 <= 4.0
        or zr7 * zr7 + zi7 * zi7 <= 4.0))
| then |> esc8(i: i + 1, ph: if (ph == 3) @as(i64, 0) else ph + 1, ci,
    cr0, cr1, cr2, cr3,
    cr4, cr5, cr6, cr7,
    zr0: zr0 * zr0 - zi0 * zi0 + cr0, zi0: 2.0 * zr0 * zi0 + ci,
    zr1: zr1 * zr1 - zi1 * zi1 + cr1, zi1: 2.0 * zr1 * zi1 + ci,
    zr2: zr2 * zr2 - zi2 * zi2 + cr2, zi2: 2.0 * zr2 * zi2 + ci,
    zr3: zr3 * zr3 - zi3 * zi3 + cr3, zi3: 2.0 * zr3 * zi3 + ci,
    zr4: zr4 * zr4 - zi4 * zi4 + cr4, zi4: 2.0 * zr4 * zi4 + ci,
    zr5: zr5 * zr5 - zi5 * zi5 + cr5, zi5: 2.0 * zr5 * zi5 + ci,
    zr6: zr6 * zr6 - zi6 * zi6 + cr6, zi6: 2.0 * zr6 * zi6 + ci,
    zr7: zr7 * zr7 - zi7 * zi7 + cr7, zi7: 2.0 * zr7 * zi7 + ci): r -> r
| else |> b8(s0: zr0 * zr0 + zi0 * zi0, s1: zr1 * zr1 + zi1 * zi1,
    s2: zr2 * zr2 + zi2 * zi2, s3: zr3 * zr3 + zi3 * zi3,
    s4: zr4 * zr4 + zi4 * zi4, s5: zr5 * zr5 + zi5 * zi5,
    s6: zr6 * zr6 + zi6 * zi6, s7: zr7 * zr7 + zi7 * zi7): r -> r

// oneb — one byte-group: all-interior fast path emits 0xFF,
// else runs the 8-lane lockstep escape
pub tor oneb { x: i64, ci: f64, ti: i64 } -> i64
oneb = if(ti == 1)
| then |> allin(cr0: crs[@as(usize, @intCast(x + 0))],
    cr1: crs[@as(usize, @intCast(x + 1))],
    cr2: crs[@as(usize, @intCast(x + 2))],
    cr3: crs[@as(usize, @intCast(x + 3))],
    cr4: crs[@as(usize, @intCast(x + 4))],
    cr5: crs[@as(usize, @intCast(x + 5))],
    cr6: crs[@as(usize, @intCast(x + 6))],
    cr7: crs[@as(usize, @intCast(x + 7))],
    ci): ai
    |> if(ai == 1)
    | then |> pb(b: 255): _ -> 0
    | else |> esc8(i: 0, ph: 0, ci,
        cr0: crs[@as(usize, @intCast(x + 0))],
        cr1: crs[@as(usize, @intCast(x + 1))],
        cr2: crs[@as(usize, @intCast(x + 2))],
        cr3: crs[@as(usize, @intCast(x + 3))],
        cr4: crs[@as(usize, @intCast(x + 4))],
        cr5: crs[@as(usize, @intCast(x + 5))],
        cr6: crs[@as(usize, @intCast(x + 6))],
        cr7: crs[@as(usize, @intCast(x + 7))],
        zr0: 0.0, zi0: 0.0, zr1: 0.0, zi1: 0.0,
        zr2: 0.0, zi2: 0.0, zr3: 0.0, zi3: 0.0,
        zr4: 0.0, zi4: 0.0, zr5: 0.0, zi5: 0.0,
        zr6: 0.0, zi6: 0.0, zr7: 0.0, zi7: 0.0): byte
        |> pb(b: byte): _ -> 0
| else |> esc8(i: 0, ph: 0, ci,
    cr0: crs[@as(usize, @intCast(x + 0))],
    cr1: crs[@as(usize, @intCast(x + 1))],
    cr2: crs[@as(usize, @intCast(x + 2))],
    cr3: crs[@as(usize, @intCast(x + 3))],
    cr4: crs[@as(usize, @intCast(x + 4))],
    cr5: crs[@as(usize, @intCast(x + 5))],
    cr6: crs[@as(usize, @intCast(x + 6))],
    cr7: crs[@as(usize, @intCast(x + 7))],
    zr0: 0.0, zi0: 0.0, zr1: 0.0, zi1: 0.0,
    zr2: 0.0, zi2: 0.0, zr3: 0.0, zi3: 0.0,
    zr4: 0.0, zi4: 0.0, zr5: 0.0, zi5: 0.0,
    zr6: 0.0, zi6: 0.0, zr7: 0.0, zi7: 0.0): byte
    |> pb(b: byte): _ -> 0

// pix8 — byte-group loop
pub tor pix8 { x: i64, ci: f64, ti: i64 } -> i64
pix8 = if(x < 400)
| then |> oneb(x, ci, ti): _
    |> pix8(x: x + 8, ci, ti): r -> r
| else -> 0

// rowl — one image row: ci = 2y/h - 1
pub tor rowl { y: i64 } -> i64
rowl = if(y < 400)
| then |> pix8(x: 0, ci: 2.0 * @as(f64, @floatFromInt(y)) / 400.0 - 1.0, ti: if (2.0 * @as(f64, @floatFromInt(y)) / 400.0 - 1.0 <= 0.66 and 2.0 * @as(f64, @floatFromInt(y)) / 400.0 - 1.0 >= -0.66) @as(i64, 1) else @as(i64, 0)): _
    |> rowl(y: y + 1): r -> r
| else -> 0

// onerun — append one P4 image to the doc
pub tor onerun { } -> i64
onerun = lit(t: "P4"): _
    |> pb(b: 10): _
    |> lit(t: "400 400"): _
    |> pb(b: 10): _
    |> rowl(y: 0): _ -> 0

// runl — 120 runs (100 measured + 20 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 120)
| then |> onerun(): _
    |> runl(k: k + 1): r -> r
| else -> 0

// djdoc — checksumBytes: DJB2 over all emitted doc bytes → st.t3
pub tor djdoc { i: i64 } -> i64
djdoc = if(i < st.p)
| then |> std/store:stored { st.t3: (st.t3 * 33 + ds[@as(usize, @intCast(i))]) & 4294967295 }
    |> djdoc(i: i + 1): r -> r
| else -> 0

// ---- driver ----
crinit(i: 0): _
|> runl(k: 0): _
|> std/store:stored { st.t3: 5381 }
|> djdoc(i: 0): _
|> std/io:print.ln("{{ st.t3:d }}")
