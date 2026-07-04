// powmod — sum of i^20 mod P for i in [1, 1000000), naive repeated multiply:
// powmod(base, e, acc) = e==0 ? acc : powmod(base, e-1, (acc*base) mod P),
// outer fold acc = (acc + powmod(i,20,1)) mod P. Faithful port of
// reference/cases/powmod (oracle 980475159). Same multi-arg tail
// self-recursion shape as gcdsum/nestedloop (parallel-assign pins
// 320_121/320_122). Single-return form: ONE output — scalar `-> i64`.
import std/io

pub event pow-mod { base: i64, e: i64, acc: i64 } -> i64

pow-mod = if(e == 0)
| then -> acc
| else |> pow-mod(base, e: e - 1, acc: @rem(acc * base, 1000000007)): v -> v

capture { acc: 0[i64] }
! as a |> for(1..1000000)
    ! each i |> pow-mod(base: @as(i64, @intCast(i)), e: 20, acc: 1): p |> captured { acc: @rem(a.acc + p, 1000000007) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
