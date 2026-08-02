// add_remove_component — add then remove a component on 10,000 entities.
// This is ecs_bench_suite's archetype-migration workload; the koru shape pin
// is 690_122_presence_column_add_remove.
//
// CATEGORY BOUNDARY — NEVER a win-quote. In the reference engines "add a
// component" migrates the entity's whole row between archetype tables: every
// existing component value is copied into the destination table and the old
// row is deleted, per entity, twice per iteration. Under O13 (capability is
// DATA, never schema membership) there is nothing to migrate: "add" is one
// i64 write to a presence column, "remove" is the same write with 0, and no
// row ever moves. Same workload name, categorically different operation.
// The number below is what OUR operation costs; the baseline is what THEIRS
// costs. The reader compares; this file does not.
//
// Protocol: 10,000 rows { hp, b }; 100 untimed warmup passes; then a timed
// block of 1000 set-passes (query writing b: 1) and a timed block of 1000
// clear-passes (query writing b: 0), each printing its own total_ns line —
// the runner SUMS total_ns lines, so per-iteration ns = (t_set + t_clear) /
// 1000, one iteration = add-on-all + remove-on-all, matching the reference
// accounting. The reference interleaves add and remove each iteration; a
// query has no completion branch to chain two passes inside one loop, so
// ours runs the set-passes consecutively then the clear-passes. For this
// model the split is the same instruction stream — the write is
// unconditional, so a second consecutive set costs exactly what an
// alternated one does. (In an archetype engine it would NOT be — a repeated
// add is a no-op with no migration — which is why their harness must
// interleave and ours merely mirrors the accounting.)
//
// Checksum: an idempotent workload's final state cannot encode its pass
// count (upstream checks nothing at all). The oracle verifies the presence
// semantics and row survival instead: after the timed blocks, one set-pass
// then a guarded query accumulates hp over rows with b == 1 (+10000), one
// clear-pass then the same guard (+0), and a full query accumulates hp over
// every surviving row (+10000). checksum 20000.
//
// Spellings grounded in passing koru regression tests:
//   presence write + `when` guard          690_122_presence_column_add_remove
//   cross-store accumulate in a query      690_096_refused_store_decl_does_not_cascade
//   insert under for-each, capacity        690_047, 690_011
//   clock bind + for `| done` chain        910/2111, and simple_iter_1col.k (measured)
import std/io
import std/store
import std/time

std/store:new(ents, capacity: 10000) { hp: i64, b: i64 }
std/store:new(check) { sum: 0[i64] }
std/store:new(out) { v: 0[i64] }

std/store:watch(out)
! v x |> std/io:print.ln("checksum {{ x:d }}")

for(0..10000)
! each _ |> std/store:insert(ents) { hp: 1, b: 0 }

for(0..100)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.b: 1 }

for(0..100)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.b: 0 }

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.b: 1 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}")

std/time:now(): tstart |> for(0..1000)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.b: 0 }
| done |> std/time:elapsed(start: tstart): td |> std/io:print.ln("total_ns {{ td.ns:d }}") |> std/io:print.ln("timed_iters 1000")

std/store:query(ents)
! query e |> std/store:stored { e.b: 1 }

std/store:query(ents)
! query g when g.b == 1 |> std/store:stored { check.sum: check.sum + g.hp }

std/store:query(ents)
! query e |> std/store:stored { e.b: 0 }

std/store:query(ents)
! query g when g.b == 1 |> std/store:stored { check.sum: check.sum + g.hp }

std/store:query(ents)
! query e |> std/store:stored { check.sum: check.sum + e.hp }

std/store:stored { out.v: check.sum }
