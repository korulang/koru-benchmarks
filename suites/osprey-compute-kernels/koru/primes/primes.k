// primes — count primes below 200000 by trial division:
// has_factor(n,d) = d*d>n ? 0 : n%d==0 ? 1 : has_factor(n,d+1);
// is_prime(n) = n<2 ? 0 : !has_factor(n,2). Faithful port of
// reference/cases/primes (oracle 17984). Tail recursion with a three-way
// branch (nested `| else |> if(...)` per 810_121); booleans are i64 0/1
// as in mutual.k; C's `!has_factor` is `1 - h`.
import std/io

pub event has-factor { n: i64, d: i64 } -> i64

has-factor = if(d * d > n)
| then -> 0
| else |> if(@rem(n, d) == 0)
    | then -> 1
    | else |> has-factor(n, d: d + 1): v -> v

pub event is-prime { n: i64 } -> i64

is-prime = if(n < 2)
| then -> 0
| else |> has-factor(n, d: 2): h -> 1 - h

capture { acc: 0[i64] }
! as a |> for(2..200000)
    ! each i |> is-prime(n: @as(i64, @intCast(i))): p |> captured { acc: a.acc + p }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
