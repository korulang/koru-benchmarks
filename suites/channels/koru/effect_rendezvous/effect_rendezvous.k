// effect_rendezvous — 1,000,000 usize values handed across an effect
// branch. `feed`'s own impl drives for(0..n) and fires `! send` per
// element; the handler at the invocation site accumulates into `acc`,
// the fire returns, the loop continues. No ring, no queue, no parking —
// a rendezvous is a statically-dispatched call here. Same checksum
// oracle as chan_throughput: sum(0..1000000) = 499999500000.
import std/io
import std/store
import std/control

std/store:new(acc) { sum: 0[i64] }

pub tor feed { n: usize }
! send i64
| done

feed = for(0..n)
! each i |> send(@as(i64, @intCast(i)))
| done => done

feed(n: 1000000)
! send v |> std/store:stored { acc.sum: acc.sum + v }
| done |> std/io:print.ln("{{ acc.sum:d }}")
