import std/io
import std/control
import std/benchmarking

capture { sink: 0[i64], ms: 0[f64] }
! as s |> std/benchmarking:run(seconds: 1)
    ! pass |> capture { sum: 0[i64] }
        ! as acc |> for(1..10_000_001)
            ! each i when i % 2 == 0 |> captured { sum: acc.sum + @as(i64, @intCast(i)) * 3 }
            | done |> _
        | captured fin |> captured { sink: fin.sum }
    | done r |> captured { ms: r.seconds * 1000.0 / @as(f64, @floatFromInt(r.passes)) }
| captured fin |> std/io:print.ln("RESULT {{ fin.sink:d }} {{ fin.ms:d }}")
