// gcdsum — sum of gcd(i, 1234567) over i in [1, 2000000). Faithful port
// (oracle 7201567) of Osprey's range(1,2000000) |> fold(0, step),
// step(acc,i)=acc+gcd(i,1234567), gcd Euclid recursion. Probes whether pure
// Koru can chain a recursive value-event call inside a `! each` fold body.
import std/io

pub event gcd { a: i64, b: i64 }
| value i64

gcd = if(b == 0)
| then => value a
| else |> gcd(a: b, b: @rem(a, b))
    | value v => value v

capture { acc: 0[i64] }
! as s |> for(1..2000000)
    ! each i |> gcd(a: @as(i64, @intCast(i)), b: 1234567)
        | value g |> captured { acc: s.acc + g }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
