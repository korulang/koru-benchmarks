// test.k — Kostya benchmarks matmul task, Koru entry.
//
// Same program shape as matmul.zig / matmul.rs:
//   argv:      n = parse(argv[1]) or 100 on missing/unparseable — the
//              reference's `parseInt(usize, arg, 10) catch 100` exactly;
//              "-5" is unparseable-as-usize there and a negative here
//              falls back the same way.
//   verify:    calc(101) must land within 0.1 of -18.67 — the reference
//              panics on miss; we print VERIFY_FAIL and never announce
//              on :9001, same observable contract.
//   timed:     send-pid, calc(n), send("stop") — matrix generation AND
//              multiply inside the bracket, exactly the reference's
//              timed find-region.
//   output:    print c[size/2][size/2] as f64 — one result line.
//
// Faithfulness differences, stated:
// - Matrices are static flat row-major grids (stride n, a[i*n+j]), not
//   the reference's [][]f64 with per-row allocations — 2.25M f64 per
//   grid, allocated once at process start in both shapes (the reference
//   arena-bumps; the measured work is arithmetic, not the allocator).
// - matMul here is the i-k-j row-streamed form (c[i][j] += a[i][k]*b[k][j],
//   a[i][k] hoisted into a scalar) where the reference transposes b and
//   takes dot products. Both accumulate c[i][j] over k in ascending
//   order from zero — bit-identical products and sums; the difference
//   is memory-access order, the disclosed performance moat.
// - n is capped at 1500 by the static grids; the suite passes MSIZE=1500.
//   A larger arg prints BOUND_FAIL rather than corrupting memory — the
//   reference would happily alloc more, disclosed bound.
//
// Liveness: the only timed call's result is printed; the grids' stores
// are consumed by the returned element — nothing to elide.

import std/io
import std/args
import std/string
import std/grid
import std/store

std/compiler:paths { notify: ./notify.kz }

import notify

std/grid:new(a, size: 2250000) { v: 0.0[f64] }
std/grid:new(b, size: 2250000) { v: 0.0[f64] }
std/grid:new(c, size: 2250000) { v: 0.0[f64] }

std/store:new(st) { n: 0[i64] }

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

// size = n/2*2 — the reference's even-size clamp on odd n, verbatim.
pub tor calc { n: usize } -> f64
calc = prep(n: @divTrunc(n, 2) * 2) |> mul(n: @divTrunc(n, 2) * 2) |> idv(v: c[@divTrunc(n, 2) * @divTrunc(n, 2) * 2 + @divTrunc(n, 2)].v): r -> r

// argv[1] -> n; missing or unparseable is 100 (the reference's catch),
// a negative parse result is the usize-parse failure the reference also
// maps to 100. Resolution lands in st.n so sibling arms reconverge.
std/args:get(index: 1)
| arg a |> std/string:parse-int(s: a)
    | ok nv |> if(nv < 0)
        | then |> std/store:stored { st.n: 100 }
        | else |> std/store:stored { st.n: nv }
    | err _ |> std/store:stored { st.n: 100 }
| out-of-bounds |> std/store:stored { st.n: 100 }
|> calc(n: 101): vchk
|> if(@abs(vchk + 18.67) > 0.1)
    | then |> std/io:print.ln("VERIFY_FAIL")
    | else |> if(st.n > 1500)
        | then |> std/io:print.ln("BOUND_FAIL")
        | else |> notify:send-pid(name: "Koru", port: 9001): _
            |> calc(n: @as(usize, @intCast(st.n))): res
            |> notify:send(msg: "stop", port: 9001): _
            |> std/io:print.ln("{{ res:f }}")
