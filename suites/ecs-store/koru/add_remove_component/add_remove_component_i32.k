// add_remove_component_i32 — the NARROW-PRESENCE variant. Identical workload
// to add_remove_component.k; the only change is `hp: i64, b: i64` becoming
// `hp: i32, b: i32`, halving the bytes each pass touches.
//
// WHY THIS PORT EXISTS. O13 rules that presence is DATA, not schema
// membership — and today that datum costs eight bytes per row to say one bit.
// The reference engines pay archetype row migration instead, so this is not a
// cross-engine question at all; it is a question about our own layout, asked
// with the cheapest possible experiment. If the entry is bandwidth-bound the
// i32 form should approach 2x; whatever it actually returns bounds what a
// narrower presence encoding could ever be worth before anyone builds one.
//
// The accumulator stays i64: an i32 column read into i64 arithmetic widens
// losslessly (narrowing is the refusal, 690_020 tier 1). Checksum is
// unchanged at 20000 — same rows, same guard semantics, same survival count.
//
// CATEGORY BOUNDARY unchanged: ours is a presence-column write, theirs is a
// per-entity row migration between archetype tables. Never a win-quote.
import std/io
import std/store
import std/time

std/store:new(ents, capacity: 10000) { hp: i32, b: i32 }
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
