// chan_custody — the chan_throughput workload with an OBLIGATION as the
// payload: 1,000,000 Src<live!> values through a capacity-1024 channel,
// four competing consumers, one thread. Same pass schedule, same checksum
// oracle — the difference is that every value in flight is a live
// obligation the compiler tracks. `| ok` consumes the producer's custody;
// `| full`/`| closed` retain it, so the producer disposes the unsent mint
// itself (the same id is re-minted next pass — the oracle sums ids, not
// obligation instances). Delivery mints a fresh obligation at the winning
// `!` arm; `dispose` discharges it. A consumer that dropped `v` would be
// a compile error (KORU030) — the ledger is checked statically and erases
// at codegen, which is exactly what the matching runtime number proves.
import std/io
import std/proto
import std/store
import std/channel
import std/pump

std/proto(Src) { id: i64 }

pub tor mk { i: i64 } -> Src<live!>
mk -> { id: i }

pub tor dispose { s: Src<!live> } -> i64
dispose -> s.id

std/channel:new(inbox, capacity: 1024) { src: Src }

std/store:new(acc) { sum: 0[i64] }
std/store:new(prod) { seq: 0[i64] }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/store:stored { acc.sum: acc.sum + id }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/store:stored { acc.sum: acc.sum + id }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/store:stored { acc.sum: acc.sum + id }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/store:stored { acc.sum: acc.sum + id }

pub tor feed { i: i64, left: i64 } -> i64
feed = if(left == 0)
| then -> 0
| else |> mk(i): v |> std/channel:send(inbox, v)
    | ok |> if(i + 1 == 1000000)
        | then |> std/channel:close(inbox)
            | ok -> 1
        | else |> feed(i: i + 1, left: left - 1): m -> 1 + m
    | full |> dispose(s: v) -> 0
    | closed |> dispose(s: v) -> 0

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
