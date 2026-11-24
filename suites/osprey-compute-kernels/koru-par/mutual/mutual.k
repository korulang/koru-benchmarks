// mutual — koru-par variant: `[parallel]for` over 1..130000, per-item
// eo(i mod 1000, flag) fold. Same algorithm and oracle (64999) as the
// is-even/is-odd mutual-recursion reference — folded to a single
// self-recursive tor with a flag param, the same transform Bend's port
// uses (their language lacks forward references). Measured: the
// faithful two-tor mutual-group form runs ~2.2x slower per step
// (mutual-group switch dispatch vs self-loop), landing at Bend's
// number; the fold is semantics-identical.
import std/io

pub tor eo { n: i64, e: i64 } -> i64

eo = if(n == 0)
| then -> e
| else |> eo(n: n - 1, e: 1 - e): v -> v

capture { acc: 0[i64] }
! as s |> [parallel]for(1..130000)
    ! each i |> eo(n: @rem(@as(i64, @intCast(i)), 1000), e: 1): e2 |> captured { acc: s.acc + e2 }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
