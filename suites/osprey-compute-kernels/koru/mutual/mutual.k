// mutual — mutually-recursive isEven/isOdd applied across a range.
// Faithful port of Osprey's range(1,130000) |> fold(0, step), where
// step(acc,i) = isEven(i mod 1000) ? acc+1 : acc, isEven/isOdd defined by
// classic mutual recursion (isEven(0)=true/1, isOdd(0)=false/0). Booleans are
// modeled as i64 0/1 value events (no grounded `| value bool` in the corpus);
// acc + e is the same naive algorithm as the ternary (e is 1 or 0). Oracle 64999.
// Single-return form: is-even/is-odd each have ONE output — scalar `-> i64`
// bare returns, no single-variant tag unions.
import std/io

pub event is-even { n: i64 } -> i64

pub event is-odd { n: i64 } -> i64

is-even = if(n == 0)
| then -> 1
| else |> is-odd(n: n - 1): v -> v

is-odd = if(n == 0)
| then -> 0
| else |> is-even(n: n - 1): v -> v

capture { acc: 0[i64] }
! as s |> for(1..130000)
    ! each i |> is-even(n: @rem(@as(i64, @intCast(i)), 1000)): e |> captured { acc: s.acc + e }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
