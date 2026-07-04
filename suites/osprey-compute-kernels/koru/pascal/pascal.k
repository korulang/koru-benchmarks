// pascal — binomial coefficient C(27,13) via the naive recurrence
// C(n,k) = C(n-1,k-1) + C(n-1,k), bases k==0 and k==n. Faithful port of
// reference/cases/pascal (oracle 20058300). Three-way branch (nested
// `| else |> if(...)` per collatz.k/primes.k) + two recursive calls
// combined via the multi-bind produce (fib.k shape).
import std/io

pub event binom { n: i64, k: i64 } -> i64

binom = if(k == 0)
| then -> 1
| else |> if(k == n)
    | then -> 1
    | else |> binom(n: n - 1, k: k - 1): a |> binom(n: n - 1, k): b -> a + b

binom(n: 27, k: 13): r |> std/io:print.ln("{{ r:d }}")
