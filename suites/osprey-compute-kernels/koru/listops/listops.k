// listops — build then traverse a pseudo-random int list (sum +
// count-below-500), 8 iterations with rolling seeds. Faithful port of
// reference/cases/listops (oracle 15992435) on the oracle-checked path:
// seed line "0"/empty -> seed 1, hashAt(seed,i) = r1(r1(seed+i)) with
// r1(x) = x*16807 mod 2147483647, BIG_MOD = 1e9+7.
//
// Faithfulness differences, stated:
// - The .osp reference builds a persistent List<int> via listAppend;
//   the suite's own Rust/C ports use a flat vector/array. This port uses
//   a std/grid of 4000 i64 — the same flat shape as the reference
//   ports, overwritten per iteration, no structural persistence.
// - sum/below are linear folds over the grid, matching the reference's
//   two traversals.
// - KNOWN GAP (same as textstats/exprtree): mode "1" draws a
//   crypto-random seed; Koru stdlib has no random builtin, so nonzero
//   seeds pass through unchanged. Mode 1 is never oracle-checked.
import std/io
import std/grid

std/grid:new(xs, size: 4000) { v: 0[i64] }

pub tor to-int { s: string } -> i64

to-int = capture { n: 0[i64] }
! as zz |> for(s)
    ! each ch |> captured { n: zz.n * 10 + (ch - 48) }
| captured r -> r.n

pub tor seed-of { v: i64 } -> i64

seed-of = if(v == 0)
| then -> 1
| else -> v

pub tor r1 { x: i64 } -> i64

r1 -> @rem(x * 16807, 2147483647)

pub tor hash-at { s: i64, i: i64 } -> i64

hash-at = r1(x: s + i): h1 |> r1(x: h1): h2 -> h2

capture { seed: 1[i64] }
! as sd |> std/io:read-lines()
    ! line l |> to-int(s: l): v |> seed-of(v): sv |> captured { seed: sv }
    | done _ |> _
    | failed _ |> captured { sd.seed }
| captured sr |> capture { acc: 0[i64], s: 0[i64] }
    ! as a |> for(0..8)
        ! each t |> captured { s: sr.seed + @as(i64, @intCast(t)) * 131 }
            |> for(0..4000)
                ! each i |> hash-at(a.s, i: @as(i64, @intCast(i))): h |> std/grid:stored { xs[@as(usize, @intCast(i))].v: @rem(h, 1000) }: _
            |> for(0..4000)
                ! each i |> captured { acc: @rem(@rem(a.acc + xs[@as(usize, @intCast(i))].v, 1000000007) + @as(i64, @intFromBool(xs[@as(usize, @intCast(i))].v < 500)), 1000000007) }
    | captured res |> std/io:print.ln("{{ res.acc:d }}")
