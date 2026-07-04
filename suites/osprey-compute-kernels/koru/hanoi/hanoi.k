// hanoi — move-count recurrence hanoi(n, acc) = n==0 ? acc :
// hanoi(n-1, hanoi(n-1, acc) + 1), evaluated at hanoi(25, 0). Faithful
// port of reference/cases/hanoi (oracle 33554431). Inner recursive result
// feeds the outer recursive call's arg — the nestedloop chain shape.
import std/io

pub event hanoi { n: i64, acc: i64 } -> i64

hanoi = if(n == 0)
| then -> acc
| else |> hanoi(n: n - 1, acc): h |> hanoi(n: n - 1, acc: h + 1): v -> v

hanoi(n: 25, acc: 0): r |> std/io:print.ln("{{ r:d }}")
