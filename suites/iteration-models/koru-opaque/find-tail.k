import std/io
import std/args
import std/control
import std/benchmarking

pub tor scan { n: usize, target: i64 }
! visit i64 -> bool
| found i64
| done

scan = capture { stop: 0[i64], hit: -1[i64] }
! as c |> for(0..n, keep: c.stop == 0)
    ! each i |> visit(@as(i64, @intCast(i))): keepgoing
        |> captured { stop: @as(i64, @intFromBool(keepgoing == false)), hit: @as(i64, @intCast(i)) }
    | done |> _
| captured fin |> if(fin.stop == 1)
    | then => found fin.hit
    | else => done

capture { sink: 0[i64], ms: 0[f64] }
! as s |> std/benchmarking:run(seconds: 1)
    ! pass |> std/args:count(): argc |> capture { hit: 0[i64] }
        ! as acc |> scan(n: 10_000_000 + argc, target: 9_999_998)
            ! visit v -> v != 9_999_998
            | found f |> captured { hit: f }
            | done |> _
        | captured fin |> captured { sink: fin.hit }
    | done r |> captured { ms: r.seconds * 1000.0 / @as(f64, @floatFromInt(r.passes)) }
| captured fin |> std/io:print.ln("RESULT {{ fin.sink:d }} {{ fin.ms:d }}")
