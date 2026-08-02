// simple_iter_f32 — the WIDTH-FAITHFUL variant of simple_iter: the reference
// Position/Velocity are f32 vec3 (cgmath Vector3<f32>), and so are these
// columns. Identical protocol, workload and checksum arithmetic; only the
// ents store's column type differs. The checksum accumulator stays f64 — an
// f32 column read into f64 arithmetic widens losslessly (narrowing is the
// refusal pinned at koru 690_160). Every partial sum is an even integer
// below 2^25, exact in f32, so the checksum is identical across widths.
import std/io
import std/store
import std/time

std/store:new(ents, capacity: 10000) { px: f32, py: f32, pz: f32, vx: f32, vy: f32, vz: f32 }
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
