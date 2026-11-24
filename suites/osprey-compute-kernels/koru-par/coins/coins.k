// coins — koru-par variant: `[parallel]` on both ways() recursive calls
// (balanced-fork shape, same as koru-par/fib). Same algorithm, oracle
// unchanged (116727). Faithful port of reference/cases/coins.
import std/io

pub tor coin { k: i64 } -> i64

coin = if(k == 1)
| then -> 1
| else |> if(k == 2)
    | then -> 5
    | else |> if(k == 3)
        | then -> 10
        | else |> if(k == 4)
            | then -> 25
            | else -> 50

pub tor ways { amount: i64, kind: i64 } -> i64

ways = if(amount == 0)
| then -> 1
| else |> if(amount < 0)
    | then -> 0
    | else |> if(kind == 0)
        | then -> 0
        | else |> coin(k: kind): c |> [parallel]ways(amount: amount - c, kind): a |> [parallel]ways(amount, kind: kind - 1): b -> a + b

ways(amount: 600, kind: 5): r |> std/io:print.ln("{{ r:d }}")
