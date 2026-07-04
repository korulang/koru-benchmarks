// fib — naive recursive Fibonacci, fib(35). Faithful port of
// reference/cases/fib (oracle 9227465). The tree-recursion probe: TWO
// recursive calls whose results combine in the produce — chained binds
// (nestedloop shape) with the final `-> a + b` reading BOTH binds.
import std/io

pub event fib { n: i64 } -> i64

fib = if(n < 2)
| then -> n
| else |> fib(n: n - 1): a |> fib(n: n - 2): b -> a + b

fib(n: 35): r |> std/io:print.ln("{{ r:d }}")
