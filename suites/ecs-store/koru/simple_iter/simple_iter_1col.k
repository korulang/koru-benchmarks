// simple_iter — ONE-COLUMN SLICE. Each timed pass advances ONE f64 column
// through the sweep arm's row (px += vx) over a 10,000-row store. This is
// NOT the full pos += vel workload: that writes three position columns per
// row and lives in simple_iter.k, blocked today on the multi-column stored
// write (KORU161, koru pin 690_118_sweep_arm_writes_two_columns).
//
// Protocol: insert 10k rows, 100 untimed warmup passes, then 1000 timed
// passes bracketed by std/time:now()/elapsed. total_ns / timed_iters is the
// per-iteration figure. The `timed_iters` print must state the same count
// as the timed for(0..N) loop above it — they are one constant spelled at
// two sites, and the runner divides by the printed value.
//
// The checksum is the correctness oracle: 1100 passes x vx=1.0 leaves every
// px at 1100.0, and the sum over 10k rows is 11000000. The accumulator
// (check) is unwatched so the 10k accumulate writes stay silent; the single
// write to `out` fires its watch once.
//
// Spellings grounded in passing koru regression tests:
//   f64 columns + sweep/stored write     690_111_plural_f64_columns_sweep
//   declared capacity                    690_011_store_insert_capacity_full_branch
//   insert under for-each                690_047_store_entity_take_auto_discharge_under_foreach
//   sweep nested under for-each          690_067_store_each_momentary_sweep_nested
//   clock bind + for `| done` chain      910/2111_prime_sieve_timed_loop, 430_008
//   singleton f64 store + watch          690_021_store_f64_scalar_columns, 690_001
import std/io
import std/store
import std/time

std/store:new(ents, capacity: 10000) { px: f64, py: f64, pz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(check) { sum: 0.0[f64] }
std/store:new(out) { v: 0.0[f64] }

std/store:watch(out)
! v x |> std/io:print.ln("checksum {{ x:f }}")

for(0..10000)
! each _ |> std/store:insert(ents) { px: 0.0, py: 0.0, pz: 0.0, vx: 1.0, vy: 1.0, vz: 1.0 }

for(0..100)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.px: e.px + e.vx }

std/time:now(): start |> for(0..1000)
! each _ |> std/store:sweep(ents)
    ! sweep e |> std/store:stored { e.px: e.px + e.vx }
| done |> std/time:elapsed(start): d |> std/io:print.ln("total_ns {{ d.ns:d }}") |> std/io:print.ln("timed_iters 1000")

std/store:sweep(ents)
! sweep e |> std/store:stored { check.sum: check.sum + e.px }

std/store:stored { out.v: check.sum }
