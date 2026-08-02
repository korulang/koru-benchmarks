// rf_fused_2 — the same 2 rule bodies as rf_stripe_2/rf_sweeps_2, hand-fused
// into ONE query whose stored block writes all 2 columns per row (the
// multi-column write simple_iter.k uses; koru 690_118/125). One corpus pass
// per frame serving 2 rules — the schedule O13's fusion claim says the
// stripe should reach. rf_fused_1 is program-identical to rf_sweeps_1 by
// construction (a same-measurement control). Each touched column ends at
// 1100.0. Checksum = 10000 x 2 x 1100.
import std/io
import std/store
import std/time

std/store:new(ents, capacity: 10000) { vx: f64, p1: f64, p2: f64, p3: f64, p4: f64, p5: f64, p6: f64, p7: f64, p8: f64 }
std/store:new(check) { sum: 0.0[f64] }
std/store:new(out) { v: 0.0[f64] }

std/store:watch(out)
! v x |> std/io:print.ln("checksum {{ x:f }}")

for(0..10000)
! each _ |> std/store:insert(ents) { vx: 1.0, p1: 0.0, p2: 0.0, p3: 0.0, p4: 0.0, p5: 0.0, p6: 0.0, p7: 0.0, p8: 0.0 }

for(0..100)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.p1: e.p1 + e.vx, e.p2: e.p2 + e.vx }

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.p1: e.p1 + e.vx, e.p2: e.p2 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}") |> std/io:print.ln("timed_iters 1000")

std/store:query(ents)
! query r |> std/store:stored { check.sum: check.sum + r.p1 + r.p2 + r.p3 + r.p4 + r.p5 + r.p6 + r.p7 + r.p8 }

std/store:stored { out.v: check.sum }
