// gemv-retarget spike — Koru port of the UchenML inner matmul loop
// (uchenml.tech/demos/langguess; X post: hand-written Highway kernel,
// 4 monomorphs {fp16,fp32} x {tail,no-tail}, WASM/NEON/SSE/AVX2/AVX-512).
//
// The computation: out[i] += sum_j w[j*I + i] * x[j]
//   weights column-major over i (contiguous stream — the layout that makes
//   the inner loop vectorizable), j unrolled by 4 (four independent FMA
//   chains per i-step, what his MulAdd block does by hand).
//
// Two paths, same accumulation order, differential-checked bitwise:
//   naive:  one j per pass (serial-j accumulate)
//   fast:   one j-GROUP of 4 per pass, the same left-assoc sum
// out bits must be identical between the two — the oracle is internal.
//
// I = 1024 outputs, J = 512 inputs, both power-of-two: the HasTail=false arm.
// f32 lanes: NEON=4, AVX2=8, AVX-512=16 — 1024 divisible by all of them.

import std/io
import std/grid

std/grid:new(w, size: 513024) { v: 0.0[f32] }
std/grid:new(x, size: 512) { v: 0.0[f32] }
std/grid:new(out_fast, size: 1002) { v: 0.0[f32] }
std/grid:new(out_naive, size: 1002) { v: 0.0[f32] }

std/grid:slice(w_s) { w.v }
std/grid:slice(x_s) { x.v }
std/grid:slice(of_s) { out_fast.v }
std/grid:slice(on_s) { out_naive.v }

// deterministic init — dyadic fractions only (exact in f32, no rounding)
for(0..512)
! each j |> for(0..1002)
    ! each i |> std/grid:stored {
        w_s[@as(usize, @intCast(j * 1002 + i))]: @as(f32, @floatFromInt(@as(i64, @intCast(@rem(j * 7 + i * 13, 17))) - 8)) * 0.03125
    }

for(0..512)
! each j |> std/grid:stored {
    x_s[@as(usize, @intCast(j))]: @as(f32, @floatFromInt(@as(i64, @intCast(@rem(j * 3, 11))) - 5)) * 0.0625
}

// naive path — one j per pass, serial accumulate
for(0..512)
! each j |> for(0..1002)
    ! each i |> std/grid:stored {
        on_s[@as(usize, @intCast(i))]: on_s[@as(usize, @intCast(i))] + w_s[@as(usize, @intCast(j * 1002 + i))] * x_s[@as(usize, @intCast(j))]
    }

// fast path — j unrolled by 4, one store per i per group;
// ((((of + w0x0) + w1x1) + w2x2) + w3x3) matches the naive accumulation
// order exactly, so the two paths must agree bitwise.
for(0..128)
! each jg |> for(0..1002)
    ! each i |> std/grid:stored {
        of_s[@as(usize, @intCast(i))]: of_s[@as(usize, @intCast(i))] + w_s[@as(usize, @intCast(jg * 4008 + i))] * x_s[@as(usize, @intCast(jg * 4))] + w_s[@as(usize, @intCast(jg * 4008 + 1002 + i))] * x_s[@as(usize, @intCast(jg * 4 + 1))] + w_s[@as(usize, @intCast(jg * 4008 + 2004 + i))] * x_s[@as(usize, @intCast(jg * 4 + 2))] + w_s[@as(usize, @intCast(jg * 4008 + 3006 + i))] * x_s[@as(usize, @intCast(jg * 4 + 3))]
    }

// checksum: sum of f32 bit patterns, both paths + disagreement counter
capture { bits_f: 0[i64], bits_n: 0[i64], diff: 0[i64] }
! as g |> for(0..1002)
    ! each i |> captured {
        bits_f: g.bits_f + @as(i64, @as(u32, @bitCast(of_s[@as(usize, @intCast(i))]))),
        bits_n: g.bits_n + @as(i64, @as(u32, @bitCast(on_s[@as(usize, @intCast(i))]))),
        diff: g.diff + @as(i64, @intFromBool(@as(u32, @bitCast(of_s[@as(usize, @intCast(i))])) != @as(u32, @bitCast(on_s[@as(usize, @intCast(i))]))))
    }
| captured r |> std/io:print.ln("fast={{ r.bits_f:d }} naive={{ r.bits_n:d }} diff={{ r.diff:d }}")
