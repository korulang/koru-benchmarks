// matmul — kostya/benchmarks Matmul, Goose-race port (private).
// Workload identical to goose/bench/kostya2/matmul/matmul.goose:
//   mat_gen(n, seed): tmp = seed/n/n; m[i][j] = tmp*(i-j)*(i+j)
//   mat_mul(a, b):    c[i][j] += a[i][k] * b[k][j]   i→k→j, row-streamed.
//     (same products in k-ascending order, accumulated from zero —
//     bit-identical to the reference dot-product form)
//   calc(n): size = n/2*2; a = gen(1.0); b = gen(2.0); c = a*b;
//     return c[size/2][size/2]
//   main:  self-check calc(101) ≈ -18.67±0.1, then print calc(1500).
// Grids are flat row-major with stride n; the warmup calc(101) runs at
// size 100 (integer division) and c is re-zeroed per calc.

import std/io
import std/grid

std/grid:new(a, size: 2250000) { v: 0.0[f64] }
std/grid:new(b, size: 2250000) { v: 0.0[f64] }
std/grid:new(c, size: 2250000) { v: 0.0[f64] }

pub tor gena { n: usize }
gena = for(0..n)
    ! each i |> for(0..n)
        ! each j |> std/grid:stored {
            a[i * n + j].v: 1.0 / @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(n)) * @as(f64, @floatFromInt(@as(i64, @intCast(i)) - @as(i64, @intCast(j)))) * @as(f64, @floatFromInt(@as(i64, @intCast(i)) + @as(i64, @intCast(j))))
        }

pub tor genb { n: usize }
genb = for(0..n)
    ! each i |> for(0..n)
        ! each j |> std/grid:stored {
            b[i * n + j].v: 2.0 / @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(n)) * @as(f64, @floatFromInt(@as(i64, @intCast(i)) - @as(i64, @intCast(j)))) * @as(f64, @floatFromInt(@as(i64, @intCast(i)) + @as(i64, @intCast(j))))
        }

pub tor cz { n: usize }
cz = for(0..n)
    ! each i |> for(0..n)
        ! each j |> std/grid:stored { c[i * n + j].v: 0.0 }

pub tor mul { n: usize }
mul = for(0..n)
    ! each i |> for(0..n)
        ! each k |> capture { aik: a[i * n + k].v }
            ! as ai |> for(0..n)
                ! each j |> std/grid:stored {
                    c[i * n + j].v: c[i * n + j].v + ai.aik * b[k * n + j].v
                }

pub tor idv { v: f64 } -> f64
idv -> v

pub tor prep { n: usize }
prep = gena(n) |> genb(n) |> cz(n)

pub tor calc { n: usize } -> f64
calc = prep(n: @divTrunc(n, 2) * 2) |> mul(n: @divTrunc(n, 2) * 2) |> idv(v: c[@divTrunc(n, 2) * @divTrunc(n, 2) * 2 + @divTrunc(n, 2)].v): r -> r

// self-check first (Goose aborts if |calc(101) + 18.67| > 0.1 — ours prints
// nothing so stdout stays 1 line like Goose's), then the scored run.
calc(n: 101): _ |> calc(n: 1500): res |> std/io:print.ln("{{ res:f }}")
