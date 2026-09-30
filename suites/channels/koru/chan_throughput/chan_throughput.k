// chan_throughput — 1,000,000 i64s through a capacity-1024 std/channel,
// four competing consumers, one thread. The producer is a pump participant
// (`prod-step`/`prod-live` — the named-unit join shape): each pass it feeds
// a bounded batch into the ring, `| full` ends the batch, and the send that
// lands the last value closes the channel. Consumers are `!` joins — each
// unit takes one dequeue per pass — accumulating into the `acc` row.
// The pump runs until producer `live` and channel `live` both answer 0,
// then `| drained` prints the checksum. Oracle: sum(0..1000000).
import std/io
import std/proto
import std/store
import std/channel
import std/pump

std/proto(Num) { v: i64 }

pub tor mk { i: i64 } -> Num
mk -> { v: i }

std/channel:new(inbox, capacity: 1024) { n: Num }

std/store:new(acc) { sum: 0[i64] }
std/store:new(prod) { seq: 0[i64] }

std/channel(inbox)
! n v |> std/store:stored { acc.sum: acc.sum + v.v }

std/channel(inbox)
! n v |> std/store:stored { acc.sum: acc.sum + v.v }

std/channel(inbox)
! n v |> std/store:stored { acc.sum: acc.sum + v.v }

std/channel(inbox)
! n v |> std/store:stored { acc.sum: acc.sum + v.v }

pub tor feed { i: i64, left: i64 } -> i64
feed = if(left == 0)
| then -> 0
| else |> mk(i): v |> std/channel:send(inbox, v)
    | ok |> if(i + 1 == 1000000)
        | then |> std/channel:close(inbox)
            | ok -> 1
        | else |> feed(i: i + 1, left: left - 1): m -> 1 + m
    | full -> 0
    | closed -> 0

pub tor prod-step {} -> i32
prod-step = feed(i: prod.seq, left: 128): m
    |> std/store:stored { prod.seq: prod.seq + m } -> @as(i32, @intCast(m))

pub tor prod-live {} -> i64
prod-live -> 1000000 - prod.seq

std/pump:create(main)
| drained |> std/io:print.ln("{{ acc.sum:d }}")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump(main)
! step |> prod-step()
! live |> prod-live()

std/pump:run(main)
