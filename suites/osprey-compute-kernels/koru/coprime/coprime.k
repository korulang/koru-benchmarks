// coprime — count pairs (i,j) in [1,2000]x[1,2000] with gcd(i,j)==1,
// via Euclid recursion and a recursive double loop. Faithful port of
// reference/cases/coprime (oracle 2433175): loop-j counts gcd(i,j)==1
// for j from n down to 1; loop-i accumulates loop-j totals for i from
// n down to 1. Same shapes as gcdsum.k (Euclid), nestedloop.k
// (loop events), collatz.k/primes.k (nested if).
import std/io

pub event gcd { a: i64, b: i64 } -> i64

gcd = if(b == 0)
| then -> a
| else |> gcd(a: b, b: @rem(a, b)): v -> v

pub event loop-j { i: i64, j: i64, acc: i64 } -> i64

loop-j = if(j == 0)
| then -> acc
| else |> gcd(a: i, b: j): g |> if(g == 1)
    | then |> loop-j(i, j: j - 1, acc: acc + 1): v -> v
    | else |> loop-j(i, j: j - 1, acc): v -> v

pub event loop-i { i: i64, n: i64, acc: i64 } -> i64

loop-i = if(i == 0)
| then -> acc
| else |> loop-j(i, j: n, acc: 0): jv |> loop-i(i: i - 1, n, acc: acc + jv): v -> v

loop-i(i: 2000, n: 2000, acc: 0): r |> std/io:print.ln("{{ r:d }}")
