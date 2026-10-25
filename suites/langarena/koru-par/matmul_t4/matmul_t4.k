// matmul_t4 — PARALLEL-CLASS port of LangArena Matmul::T4 (the arena's
// own threaded variant — Single's subclass that splits c's rows across a
// worker pool). NOT the serial Matmul::Single contract: that port is
// koru/matmul_single, single-threaded by class definition. This file
// keeps the same arithmetic (same k-ascending products, same oracle
// checksum) but computes row ranges on [parallel]for — which is exactly
// what T4's matmul_parallel does with threads × rows_per_worker.
//
// Measured: see below after bench run.
// matmul_single — LangArena Matmul::Single, run.js scored parameters
// (n=900, iterations=10, warmup_iterations=max(10*0.2,1)=2 → 12 checksum
// accumulations, oracle 3655420808).
//
// Faithful port of reference/crystal/main.cr Matmul::Single:
//   matgen: tmp = 1.0/n/n; m[i][j] = tmp*(i-j)*(i+j)   (deterministic, no RNG)
//   matmul: c[i][j] = sum_k a[i][k]*b[k][j]          (k ascending)
//   run:    acc += djb2("%.7f", c[n/2][n/2]) per iteration, mod 2^32
//
// Faithfulness differences, stated:
// - bt = transpose(b) is materialised once up front, matching the
//   reference's t = transpose(b) + row-zip: the inner loop then streams
//   both operands sequentially — identical products in identical
//   k-ascending order, bit-identical sum.
// - Matrices are flat static grids (i*n+j), not Array(Array(Float64)) —
//   same arithmetic, no row-pointer indirection.
// - The warmup/measured split is collapsed into one 12-iteration loop: the
//   arena separates them only for timing; the checksum accumulates identically
//   (1 warmup + 3 iters = 4 accumulations at test.js scale, verified byte-exact
//   against oracle 720656960; here 2 + 10 = 12).
// - %.7f is reproduced arithmetically: sign byte, integer digits, '.',
//   seven fraction digits — DJB2 over the same byte sequence. Round is
//   floor(mag*1e7 + 0.5); printf %.7f is round-half-even on the exact
//   decimal expansion — they diverge only on an exact .5 tie in the scaled
//   value, essentially impossible for a computed f64. -0.0 would print as
//   "-0.0000000" but v<0.0 misses the sign bit; the matmul centre value is
//   strictly negative so this does not fire here. Noted for reuse.
// - [unsafe(bounds)] is NOT waived — bounds checks stay on (the arena's
//   "hacking" variants are a separate, later decision).

import std/io
import std/grid

pub tor djb2-byte { h: i64, b: i64 } -> i64
djb2-byte -> @rem(h * 33 + b, 4294967296)

// int-part digits, most-significant first, via recursion unwind.
pub tor djb2-digits { n: i64, h: i64 } -> i64
djb2-digits = if(n < 10)
| then |> djb2-byte(h, b: 48 + n): r -> r
| else |> djb2-digits(n: @divTrunc(n, 10), h): h2 |> djb2-byte(h: h2, b: 48 + @rem(n, 10)): r -> r

// seven fraction digits, fixed width incl. leading zeros, via p = 10^6..1.
pub tor djb2-frac { fp: i64, p: i64, h: i64 } -> i64
djb2-frac = if(p == 0)
| then -> h
| else |> djb2-byte(h, b: 48 + @rem(@divTrunc(fp, p), 10)): h2 |> djb2-frac(fp, p: @divTrunc(p, 10), h: h2): r -> r

pub tor t-of { mag: f64 } -> i64
t-of -> @as(i64, @intFromFloat(@floor(mag * 10000000.0 + 0.5)))

// checksum_f64: DJB2 over the "%.7f" text of v. h pre-seeded by the caller
// (177618 = 5381*33+'-' for negative v; 5381 otherwise).
pub tor cs-tail { mag: f64, h: i64 } -> i64
cs-tail = t-of(mag): t |> djb2-digits(n: @divTrunc(t, 10000000), h): h1 |> djb2-byte(h: h1, b: 46): h2 |> djb2-frac(fp: @rem(t, 10000000), p: 1000000, h: h2): h3 -> h3

pub tor checksum-f64 { v: f64 } -> i64
checksum-f64 = if(v < 0.0)
| then |> cs-tail(mag: 0.0 - v, h: 177618): r -> r
| else |> cs-tail(mag: v, h: 5381): r -> r

std/grid:new(a, size: 810000) { v: 0.0[f64] }
std/grid:new(b, size: 810000) { v: 0.0[f64] }
std/grid:new(c, size: 810000) { v: 0.0[f64] }
std/grid:new(bt, size: 810000) { v: 0.0[f64] }

std/grid:slice(a_s) { a.v }
std/grid:slice(bt_s) { bt.v }
std/grid:slice(c_s) { c.v }

for(0..900)
! each i |> for(0..900)
    ! each j |> std/grid:stored {
        a[i * 900 + j].v: 1.0 / 900.0 / 900.0 * @as(f64, @floatFromInt(@as(i64, @intCast(i)) - @as(i64, @intCast(j)))) * @as(f64, @floatFromInt(@as(i64, @intCast(i)) + @as(i64, @intCast(j))))
    } |> std/grid:stored {
        b[i * 900 + j].v: 1.0 / 900.0 / 900.0 * @as(f64, @floatFromInt(@as(i64, @intCast(i)) - @as(i64, @intCast(j)))) * @as(f64, @floatFromInt(@as(i64, @intCast(i)) + @as(i64, @intCast(j))))
    }

for(0..900)
! each i |> for(0..900)
    ! each j |> std/grid:stored {
        bt_s[@as(usize, @intCast(j * 900 + i))]: b[i * 900 + j].v
    }

capture { acc: 0[i64] }
! as g |> for(0..12)
    ! each it |> [parallel]for(0..900)
        ! each i |> for(0..900)
            ! each j |> capture { s: 0.0[f64] }
                ! as ai |> for(0..900)
                    ! each k |> captured { s: ai.s + a_s[@as(usize, @intCast(i * 900 + k))] * bt_s[@as(usize, @intCast(j * 900 + k))] }
                | captured r |> std/grid:stored { c_s[@as(usize, @intCast(i * 900 + j))]: r.s }
        | done |> checksum-f64(v: c_s[405450]): cs |> captured { acc: @rem(g.acc + cs, 4294967296) }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
