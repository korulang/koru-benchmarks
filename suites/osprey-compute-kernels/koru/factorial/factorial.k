// factorial — product 1*2*...*N taken mod 1000000007 (real N! overflows i64).
// Faithful port (oracle 682498929): Osprey's range(1,10000001) |> fold(1, step)
// with step(acc,i)=(acc*i) mod P, as a pure-Koru scalar capture-fold.
import std/io

capture { acc: 1[i64] }
! as a |> for(1..10000001)
    ! each i |> captured { acc: @rem(a.acc * @as(i64, @intCast(i)), 1000000007) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
