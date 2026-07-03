// josephus — survivor index for the Josephus problem, step k=7, via the
// modular recurrence acc = (acc + 7) mod i for i in [2, 10_000_001).
// Faithful port of benchmarks/osprey_kernels/cases/josephus (oracle 1400177):
// Osprey's `range(2, 10000001) |> fold(0, step)` becomes a pure-Koru scalar
// capture-fold over a `for(2..10000001)` counted range.
import std/io

capture { acc: 0[i64] }
! as a |> for(2..10000001)
    ! each i |> captured { acc: @rem(a.acc + 7, @as(i64, @intCast(i))) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
