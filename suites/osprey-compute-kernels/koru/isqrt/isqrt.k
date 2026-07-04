// isqrt — sum of integer square roots over 1..1000000, Newton's method:
// isqrtIter(n,x) recomputes y = (x + n/x)/2; when y>=x it has converged
// (return x), otherwise recurse with x:y. Faithful port of
// reference/cases/isqrt (oracle 666167500). Same tail self-recursion shape
// as gcdsum/powmod/primes (base case in `then`, recursive step in `else`);
// no local `let` exists in this corpus's .k idiom, so y is written as the
// same inline expression in the condition and the recursive arg, matching
// pow-mod's style of recomputing the next-arg expression inline.
import std/io

pub event isqrt-iter { n: i64, x: i64 } -> i64

isqrt-iter = if(@divTrunc(x + @divTrunc(n, x), 2) >= x)
| then -> x
| else |> isqrt-iter(n, x: @divTrunc(x + @divTrunc(n, x), 2)): v -> v

pub event isqrt { n: i64 } -> i64

isqrt = if(n < 2)
| then -> n
| else |> isqrt-iter(n, x: n): v -> v

capture { acc: 0[i64] }
! as a |> for(1..1000001)
    ! each i |> isqrt(n: @as(i64, @intCast(i))): s |> captured { acc: a.acc + s }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
