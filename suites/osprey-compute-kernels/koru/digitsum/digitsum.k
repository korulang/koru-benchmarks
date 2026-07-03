// digitsum — sum over i in [1, 2000001) of digitSum(i), where
// digitSum(n) = n<10 ? n : (n%10) + digitSum(n/10). Faithful port
// (oracle 55000002) of Osprey's range(1,2000001) |> fold(0, step),
// step(acc,i)=acc+digsum(i), digsum non-tail recursion (add after the
// recursive call — distinct from gcdsum's tail cross-referencing shape).
// Single-return form: digit-sum has ONE output, so it is the scalar `-> i64`
// bare return — no single-variant tag union (that union was the ~2.9x
// recursion overhead this kernel used to carry).
import std/io

pub event digit-sum { n: i64 } -> i64

digit-sum = if(n < 10)
| then -> n
| else |> digit-sum(n: @divTrunc(n, 10)): v -> @rem(n, 10) + v

capture { acc: 0[i64] }
! as a |> for(1..2000001)
    ! each i |> digit-sum(n: @as(i64, @intCast(i))): d |> captured { acc: a.acc + d }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
