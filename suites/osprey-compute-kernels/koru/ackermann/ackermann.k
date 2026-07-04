// ackermann — Ackermann-Peter function: ack(m,n) = m==0 ? n+1 :
// n==0 ? ack(m-1,1) : ack(m-1, ack(m,n-1)), evaluated at ack(3,10).
// Faithful port of reference/cases/ackermann (oracle 8189). Deep
// non-tail recursion with a nested recursive argument — three-way branch
// (nested `| else |> if(...)` per 810_121 shape) plus the chained-bind
// shape from hanoi.k/tak.k for ack(m-1, ack(m, n-1)).
import std/io

pub event ack { m: i64, n: i64 } -> i64

ack = if(m == 0)
| then -> n + 1
| else |> if(n == 0)
    | then |> ack(m: m - 1, n: 1): v -> v
    | else |> ack(m, n: n - 1): inner |> ack(m: m - 1, n: inner): v -> v

ack(m: 3, n: 10): r |> std/io:print.ln("{{ r:d }}")
