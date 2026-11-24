// coprime — count pairs (i,j) in [1,2000]x[1,2000] with gcd(i,j)==1.
// Faithful port of koru/coprime (oracle 2433175): loop-j counts
// gcd(i,j)==1 for j from 2000 down to 1; the sequential loop-i then
// summed those per-i counts for i from 2000 down to 1 — a pure sum over
// independent rows, so the i-loop becomes [parallel]for + capture (same
// idiom as gcdsum/digitsum/primes). gcd and loop-j are verbatim; only
// the driver changed. Same algorithm, same parameters as the sequential
// port and as bend-par/coprime (8-way i-split, per-chunk sequential j).
import std/io

pub tor gcd { a: i64, b: i64 } -> i64

gcd = if(b == 0)
| then -> a
| else |> gcd(a: b, b: @rem(a, b)): v -> v

pub tor loop-j { i: i64, j: i64, acc: i64 } -> i64

loop-j = if(j == 0)
| then -> acc
| else |> gcd(a: i, b: j): g |> if(g == 1)
    | then |> loop-j(i, j: j - 1, acc: acc + 1): v -> v
    | else |> loop-j(i, j: j - 1, acc): v -> v

capture { acc: 0[i64] }
! as a |> [parallel]for(1..2001)
    ! each i |> loop-j(i: @as(i64, @intCast(i)), j: 2000, acc: 0): c |> captured { acc: a.acc + c }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
