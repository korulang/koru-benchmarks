// rf_stripe_8 — 8 standing rules over one 10k-row store, fired through
// std/store:stripe once per timed frame. The rules are unconstrained (no
// [depends_on]) and legally fusible per koru 690_202/690_044: disjoint write
// sets (p1, p2, p3, p4, p5, p6, p7, p8), shared read column (vx). Rule i: p_i += vx.
// Each rule fires once at its root declaration (690_200) + 100 warmup +
// 1000 timed frames, so each touched column ends at 1101.0; untouched
// columns stay 0. Checksum = 10000 x 8 x 1101.
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

[name(r1)]std/store:rule(ents)
! row s1 |> std/store:stored { s1.p1: s1.p1 + s1.vx }

[name(r2)]std/store:rule(ents)
! row s2 |> std/store:stored { s2.p2: s2.p2 + s2.vx }

[name(r3)]std/store:rule(ents)
! row s3 |> std/store:stored { s3.p3: s3.p3 + s3.vx }

[name(r4)]std/store:rule(ents)
! row s4 |> std/store:stored { s4.p4: s4.p4 + s4.vx }

[name(r5)]std/store:rule(ents)
! row s5 |> std/store:stored { s5.p5: s5.p5 + s5.vx }

[name(r6)]std/store:rule(ents)
! row s6 |> std/store:stored { s6.p6: s6.p6 + s6.vx }

[name(r7)]std/store:rule(ents)
! row s7 |> std/store:stored { s7.p7: s7.p7 + s7.vx }

[name(r8)]std/store:rule(ents)
! row s8 |> std/store:stored { s8.p8: s8.p8 + s8.vx }

for(0..100)
! each _ |> std/store:stripe(ents)

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:stripe(ents)
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}") |> std/io:print.ln("timed_iters 1000")

std/store:query(ents)
! query r |> std/store:stored { check.sum: check.sum + r.p1 + r.p2 + r.p3 + r.p4 + r.p5 + r.p6 + r.p7 + r.p8 }

std/store:stored { out.v: check.sum }
