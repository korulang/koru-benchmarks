// simple_iter — the FULL pos += vel workload: three position columns advanced
// by three velocity columns per row, 10,000 rows per pass. Columns are f64
// (the store's pinned scalar column type, 690_021); the reference engines use
// f32 vec3 — twice our per-column memory traffic.
//
// This was BLOCKED until koru pins 690_118 / 690_125 landed: a `stored` block
// writing more than one column of the queried row was refused with KORU161
// "unknown store 'ents[__koru_srow_e_...]'". Both pins are green and this
// file compiles and runs unchanged, as written.
//
// Protocol and checksum mirror simple_iter_1col.k: 100 warmup + 1000 timed
// passes, per-iteration ns = total_ns / timed_iters. Checksum: px = py = pz =
// 1100.0 after 1100 passes, summed over 10k rows and three columns =
// 33000000.
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
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.px: e.px + e.vx, e.py: e.py + e.vy, e.pz: e.pz + e.vz }

std/time:now(): start |> for(0..1000)
! each _ |> std/store:query(ents)
    ! query e |> std/store:stored { e.px: e.px + e.vx, e.py: e.py + e.vy, e.pz: e.pz + e.vz }
| done |> std/time:elapsed(start): d |> std/io:print.ln("total_ns {{ d.ns:d }}") |> std/io:print.ln("timed_iters 1000")

std/store:query(ents)
! query e |> std/store:stored { check.sum: check.sum + e.px + e.py + e.pz }

std/store:stored { out.v: check.sum }
