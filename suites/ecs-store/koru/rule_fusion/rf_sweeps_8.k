// rf_sweeps_8 — the same 8 rule bodies as rf_stripe_8, run as 8 separate
// imperative sweeps: 8 corpus passes per frame by construction. Each rule's
// 1000 timed passes sit in their own block (a sweep has no completion branch,
// so 8 passes cannot share one loop); the runner sums the total_ns lines and
// divides by timed_iters, giving ns per frame of 8 passes. Each touched
// column ends at 1100.0. Checksum = 10000 x 8 x 1100.
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
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p1: e.p1 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p2: e.p2 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p3: e.p3 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p4: e.p4 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p5: e.p5 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p6: e.p6 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p7: e.p7 + e.vx }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p8: e.p8 + e.vx }

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p1: e.p1 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p2: e.p2 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p3: e.p3 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p4: e.p4 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p5: e.p5 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p6: e.p6 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p7: e.p7 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.p8: e.p8 + e.vx }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}") |> std/io:print.ln("timed_iters 1000")

std/store:sweep(ents)
! sweep r |> std/store:stored { check.sum: check.sum + r.p1 + r.p2 + r.p3 + r.p4 + r.p5 + r.p6 + r.p7 + r.p8 }

std/store:stored { out.v: check.sum }
