// coins — count ways to make 600 from coin denominations [1,5,10,25,50]
// (SICP classic change-counting). Faithful port of reference/cases/coins
// (oracle 116727). coin(k) is a 5-way fixed-set lookup, built as nested
// `| else |> if(...)` per the primes.k/collatz.k three-way-branch shape,
// extended one level further. ways(amount, kind) is a four-outcome
// recurrence (amount==0 / amount<0 / kind==0 / else) — same nested-if
// shape one level deeper — whose recursive else-arm chains two binds
// (fib.k's tree-recursion shape) with unchanged-arg punning (hanoi.k's
// `hanoi(n: n - 1, acc)` pattern) for the amount/kind that don't change.
import std/io

pub event coin { k: i64 } -> i64

coin = if(k == 1)
| then -> 1
| else |> if(k == 2)
    | then -> 5
    | else |> if(k == 3)
        | then -> 10
        | else |> if(k == 4)
            | then -> 25
            | else -> 50

pub event ways { amount: i64, kind: i64 } -> i64

ways = if(amount == 0)
| then -> 1
| else |> if(amount < 0)
    | then -> 0
    | else |> if(kind == 0)
        | then -> 0
        | else |> coin(k: kind): c |> ways(amount: amount - c, kind): a |> ways(amount, kind: kind - 1): b -> a + b

ways(amount: 600, kind: 5): r |> std/io:print.ln("{{ r:d }}")
