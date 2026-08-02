// fragmented_iter_f32 — the WIDTH-FAITHFUL variant of fragmented_iter. The
// reference fragments hold f32; these columns do too, and nothing else about
// the workload changes. It exists because the board quoted a 3.2x gap to
// shipyard on this entry while comparing our f64 columns against their f32 —
// so up to half of that gap was our own missing port, not a real difference.
//
// CATEGORY BOUNDARY still applies, unchanged: the reference walks 26
// fragmented archetype tables inside one query; std/store has no archetypes,
// so each fragment is its own store and one pass is 26 independent queries.
// Never a win-quote. See MODEL.md.
//
// ONE DELIBERATE DEVIATION FROM THE f64 PORT, and it is forced. That port
// advances `data * 2.0` and normalizes with 1000 untimed halvings, so the
// checksum is an exact power of two. f32 cannot hold 2^1000 — it saturates to
// inf at 2^128 and every pass count above ~127 produces the same answer,
// which is an oracle that cannot fail. This port advances `data + 1.0`
// instead: after 100 warmup + 900 timed passes every element is exactly
// 1001.0 (well inside f32's 2^24 exact-integer range), so the oracle detects
// ANY missed or extra pass, including the whole timed loop being optimized
// away. The normalization blocks are therefore gone; they were untimed and
// existed only to make the doubling scheme finite.
//
// AND THE SOURCE DEVIATION VANISHES IN THE EMITTED CODE, which I checked
// rather than assumed. LLVM strength-reduces the f64 port's `data * 2.0`
// into `fadd.2d v0, v0, v0` — x + x. This port's `data + 1.0` emits
// `fadd.4s v1, v1, v5` — x + broadcast constant. Both timed loops are
// therefore THE SAME INSTRUCTION, a vector FP add, in the same count, both
// unrolled four vector ops deep over paired `ldp`/`stp` accesses. The only
// surviving difference between the two ports is the column width, which is
// exactly what this pair is for. (The f64 port's `fmul.2d` sites are its 26
// untimed halving blocks, outside the clock.)
//
// Protocol otherwise identical: 20 rows in each of 26 stores, 100 untimed
// warmup passes, then per store 900 timed passes bracketed by
// std/time:now()/elapsed, each block printing its own total_ns line. The
// runner SUMS total_ns, so per-iteration ns = (sum over 26 stores) / 900.
// Checksum: 26 x 20 x 1001.0 = 520520, accumulated in f64.
import std/io
import std/store
import std/time


std/store:new(ca, capacity: 20) { data: f32 }
std/store:new(cb, capacity: 20) { data: f32 }
std/store:new(cc, capacity: 20) { data: f32 }
std/store:new(cd, capacity: 20) { data: f32 }
std/store:new(ce, capacity: 20) { data: f32 }
std/store:new(cf, capacity: 20) { data: f32 }
std/store:new(cg, capacity: 20) { data: f32 }
std/store:new(ch, capacity: 20) { data: f32 }
std/store:new(ci, capacity: 20) { data: f32 }
std/store:new(cj, capacity: 20) { data: f32 }
std/store:new(ck, capacity: 20) { data: f32 }
std/store:new(cl, capacity: 20) { data: f32 }
std/store:new(cm, capacity: 20) { data: f32 }
std/store:new(cn, capacity: 20) { data: f32 }
std/store:new(co, capacity: 20) { data: f32 }
std/store:new(cp, capacity: 20) { data: f32 }
std/store:new(cq, capacity: 20) { data: f32 }
std/store:new(cr, capacity: 20) { data: f32 }
std/store:new(cs, capacity: 20) { data: f32 }
std/store:new(ct, capacity: 20) { data: f32 }
std/store:new(cu, capacity: 20) { data: f32 }
std/store:new(cv, capacity: 20) { data: f32 }
std/store:new(cw, capacity: 20) { data: f32 }
std/store:new(cx, capacity: 20) { data: f32 }
std/store:new(cy, capacity: 20) { data: f32 }
std/store:new(cz, capacity: 20) { data: f32 }

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
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cb)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cc)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cd)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(ce)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cf)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cg)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(ch)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(ci)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cj)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(ck)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cl)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cm)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cn)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(co)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cp)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cq)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cr)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cs)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(ct)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cu)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cv)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cw)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cx)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cy)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

for(0..100)
! each _ |> std/store:query(cz)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ca)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cb)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cc)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cd)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ce)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cf)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cg)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ch)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ci)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cj)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ck)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cl)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cm)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cn)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(co)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cp)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cq)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cr)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cs)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(ct)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cu)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cv)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cw)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cx)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cy)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..900)
! each _ |> std/store:query(cz)
    ! query e |> std/store:stored { e.data: e.data + 1.0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}") |> std/io:print.ln("timed_iters 900")

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
