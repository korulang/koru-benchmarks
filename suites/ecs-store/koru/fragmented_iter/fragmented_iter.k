// fragmented_iter — 26 fragments x 20 entities, `data *= 2.0` over every
// fragment per pass. This is ecs_bench_suite's archetype-fragmentation
// workload; the koru shape pin is 690_121_twenty_six_component_stores.
//
// CATEGORY BOUNDARY — NEVER a win-quote. The reference engines pay per-table
// overhead walking 26 fragmented archetypes inside one query; std/store has
// no archetypes (O13: presence is data, not schema membership), so each
// fragment is simply its own store and one pass is 26 independent queries.
// Same workload name, structurally different iteration. The number below is
// what OUR operation costs; the baseline is what THEIRS costs. The reader
// compares; this file does not.
//
// Protocol: 20 rows in each of 26 stores; 100 untimed warmup passes; then,
// per store, 900 timed passes bracketed by std/time:now()/elapsed, each
// block printing its own total_ns line — the runner SUMS total_ns lines, so
// per-iteration ns = (sum over 26 stores) / 900, one iteration = one full
// pass over all 26 fragments. A query has no completion branch to chain 26
// of them inside one loop, so the passes are store-major (each store's 900
// timed consecutively) where the reference interleaves all 26
// fragments per iteration. The whole working set is 26 x 20 x 8 B = 4160
// bytes — L1-resident in either order. Columns are f64 (the store's pinned
// scalar type, 690_021); the reference fragments hold f32 — twice our
// per-element traffic.
//
// Checksum: every element is doubled exactly 1000 times (100 warmup + 900
// timed), then halved exactly 1000 times UNTIMED — all exact powers of two,
// so any missed or extra pass leaves a value != 1.0. Sum over 26 stores x
// 20 rows x 1.0 = 520. (Upstream lets f32 saturate to inf and checks
// nothing; our oracle needs a finite exact value, so the normalization
// halvings exist for the checksum only and run outside the clock.)
//
// Spellings grounded in passing koru regression tests:
//   26 stores, one program                 690_121_twenty_six_component_stores
//   f64 columns + query/stored write       690_111, 690_021
//   insert under for-each, capacity        690_047, 690_011
//   clock bind + for `| done` chain        910/2111, and simple_iter_1col.k (measured)
import std/io
import std/store
import std/time


std/store:new(ca, capacity: 20) { data: f64 }
std/store:new(cb, capacity: 20) { data: f64 }
std/store:new(cc, capacity: 20) { data: f64 }
std/store:new(cd, capacity: 20) { data: f64 }
std/store:new(ce, capacity: 20) { data: f64 }
std/store:new(cf, capacity: 20) { data: f64 }
std/store:new(cg, capacity: 20) { data: f64 }
std/store:new(ch, capacity: 20) { data: f64 }
std/store:new(ci, capacity: 20) { data: f64 }
std/store:new(cj, capacity: 20) { data: f64 }
std/store:new(ck, capacity: 20) { data: f64 }
std/store:new(cl, capacity: 20) { data: f64 }
std/store:new(cm, capacity: 20) { data: f64 }
std/store:new(cn, capacity: 20) { data: f64 }
std/store:new(co, capacity: 20) { data: f64 }
std/store:new(cp, capacity: 20) { data: f64 }
std/store:new(cq, capacity: 20) { data: f64 }
std/store:new(cr, capacity: 20) { data: f64 }
std/store:new(cs, capacity: 20) { data: f64 }
std/store:new(ct, capacity: 20) { data: f64 }
std/store:new(cu, capacity: 20) { data: f64 }
std/store:new(cv, capacity: 20) { data: f64 }
std/store:new(cw, capacity: 20) { data: f64 }
std/store:new(cx, capacity: 20) { data: f64 }
std/store:new(cy, capacity: 20) { data: f64 }
std/store:new(cz, capacity: 20) { data: f64 }

std/store:new(check) { sum: 0.0[f64] }
std/store:new(out) { v: 0.0[f64] }

std/store:watch(out)
! v x |> std/io:print.ln("checksum {{ x:f }}")


for(0..20)
! each _ |> std/store:insert(ca) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cb) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cc) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cd) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(ce) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cf) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cg) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(ch) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(ci) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cj) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(ck) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cl) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cm) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cn) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(co) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cp) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cq) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cr) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cs) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(ct) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cu) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cv) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cw) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cx) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cy) { data: 1.0 }

for(0..20)
! each _ |> std/store:insert(cz) { data: 1.0 }

for(0..100)
! each _ |> std/store:query(ca)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cb)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cc)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cd)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(ce)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cf)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cg)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(ch)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(ci)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cj)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(ck)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cl)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cm)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cn)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(co)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cp)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cq)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cr)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cs)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(ct)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cu)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cv)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cw)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cx)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cy)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

for(0..100)
! each _ |> std/store:query(cz)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ca)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cb)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cc)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cd)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ce)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cf)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cg)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ch)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ci)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cj)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ck)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cl)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cm)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cn)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(co)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cp)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cq)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cr)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cs)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ct)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cu)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cv)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cw)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cx)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cy)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cz)
    ! query e |> std/store:stored { e.data: e.data * 2.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}") |> std/io:print.ln("timed_iters 900")

for(0..1000)
! each _ |> std/store:query(ca)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cb)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cc)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cd)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(ce)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cf)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cg)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(ch)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(ci)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cj)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(ck)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cl)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cm)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cn)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(co)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cp)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cq)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cr)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cs)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(ct)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cu)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cv)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cw)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cx)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cy)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

for(0..1000)
! each _ |> std/store:query(cz)
    ! query e |> std/store:stored { e.data: e.data * 0.5 }

std/store:query(ca)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cb)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cc)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cd)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(ce)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cf)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cg)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(ch)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(ci)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cj)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(ck)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cl)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cm)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cn)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(co)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cp)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cq)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cr)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cs)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(ct)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cu)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cv)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cw)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cx)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cy)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:query(cz)
! query e |> std/store:stored { check.sum: check.sum + e.data }

std/store:stored { out.v: check.sum }
