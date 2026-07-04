// collatz — 3n+1 stopping time summed over i in [1, 100001):
// collatz(n) = n==1 ? 0 : n%2==0 ? 1+collatz(n/2) : 1+collatz(3n+1).
// Faithful port of reference/cases/collatz (oracle 10753840). Non-tail
// single recursion (the +1 lands after the call) with a THREE-way branch:
// nested `| else |> if(...)` per the passing 810_121 shape, producing from
// nested arms via the single-return `-> i64` form.
import std/io

pub event collatz { n: i64 } -> i64

collatz = if(n == 1)
| then -> 0
| else |> if(@rem(n, 2) == 0)
    | then |> collatz(n: @divTrunc(n, 2)): v -> 1 + v
    | else |> collatz(n: 3 * n + 1): v -> 1 + v

capture { acc: 0[i64] }
! as a |> for(1..100001)
    ! each i |> collatz(n: @as(i64, @intCast(i))): c |> captured { acc: a.acc + c }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
