import std/io
import std/args
import std/control
import std/benchmarking

pub tor evens { n: usize }
! item i64 -> i64
| done i64

evens = capture { sum: 0[i64] }
! as acc |> for(1..(n + 1))
    ! each i when i % 2 == 0 |> item(@as(i64, @intCast(i))): t |> captured { sum: acc.sum + t }
    | done |> _
| captured c => done c.sum

capture { sink: 0[i64], ms: 0[f64] }
! as s |> std/benchmarking:run(seconds: 1)
    ! pass |> std/args:count(): argc |> evens(n: 10_000_000 + argc)
        ! item v -> v * 3
        | done total |> captured { sink: total }
    | done r |> captured { ms: r.seconds * 1000.0 / @as(f64, @floatFromInt(r.passes)) }
| captured fin |> std/io:print.ln("RESULT {{ fin.sink:d }} {{ fin.ms:d }}")
