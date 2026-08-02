// simple_insert — 10,000 entities x 4 components per timed pass. The row is
// the reference row flattened to SoA scalars: Transform(mat4x4) as 16 columns
// (identity, cgmath Matrix4::from_scale(1.0)), Position/Rotation/Velocity
// (vec3) as 9 columns (unit_x = 1,0,0 each). 25 columns per row; this file's
// columns are f64 — the reference components are f32; simple_insert_f32.k is
// the width-faithful variant.
//
// One store PER PASS (w for warmup, e1..e5 timed): the reference creates a
// new world every criterion iteration and batch-spawns 10k entities into it,
// so each of our passes likewise inserts into a store no insert has touched.
// Difference, stated: their world is heap-allocated inside the iteration;
// our stores are static declarations, so no allocation happens inside the
// timed region — first-touch page faults on each store's columns do.
// A store cannot be drained and reused today: a literal row index is a
// generation-0 handle (stale after its slot is reused), and take with a
// query-bound row miscompiles — see the board README's defect list.
//
// Protocol: 1 untimed warmup pass into w, then 5 timed passes into e1..e5,
// each bracketed by its own std/time:now()/elapsed printing one total_ns
// line; the runner sums the five lines and divides by timed_iters = 5.
//
// Checksum: every column of every row of all six stores. Per row: identity
// diag = 4, px+py+pz = 1, rx+ry+rz = 1, vx+vy+vz = 1 -> 7. 60,000 rows ->
// 420000.
//
// Spellings grounded in passing koru regression tests:
//   25-column all-f64 store + wide insert   690_119_flattened_mat4_vec3_row
//   many stores in one program              690_121_twenty_six_component_stores
//   insert under for-each                   690_047, simple_iter.k
//   clock bind + for `| done` chain         simple_iter.k (910/2111, 430_008)
import std/io
import std/store
import std/time

std/store:new(w, capacity: 10000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, px: f64, py: f64, pz: f64, rx: f64, ry: f64, rz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(e1, capacity: 10000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, px: f64, py: f64, pz: f64, rx: f64, ry: f64, rz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(e2, capacity: 10000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, px: f64, py: f64, pz: f64, rx: f64, ry: f64, rz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(e3, capacity: 10000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, px: f64, py: f64, pz: f64, rx: f64, ry: f64, rz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(e4, capacity: 10000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, px: f64, py: f64, pz: f64, rx: f64, ry: f64, rz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(e5, capacity: 10000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, px: f64, py: f64, pz: f64, rx: f64, ry: f64, rz: f64, vx: f64, vy: f64, vz: f64 }
std/store:new(check) { sum: 0.0[f64] }
std/store:new(out) { v: 0.0[f64] }

std/store:watch(out)
! v x |> std/io:print.ln("checksum {{ x:f }}")

for(0..10000)
! each _ |> std/store:insert(w) { t00: 1.0, t01: 0.0, t02: 0.0, t03: 0.0, t10: 0.0, t11: 1.0, t12: 0.0, t13: 0.0, t20: 0.0, t21: 0.0, t22: 1.0, t23: 0.0, t30: 0.0, t31: 0.0, t32: 0.0, t33: 1.0, px: 1.0, py: 0.0, pz: 0.0, rx: 1.0, ry: 0.0, rz: 0.0, vx: 1.0, vy: 0.0, vz: 0.0 }

std/time:now(): s1 |> for(0..10000)
! each _ |> std/store:insert(e1) { t00: 1.0, t01: 0.0, t02: 0.0, t03: 0.0, t10: 0.0, t11: 1.0, t12: 0.0, t13: 0.0, t20: 0.0, t21: 0.0, t22: 1.0, t23: 0.0, t30: 0.0, t31: 0.0, t32: 0.0, t33: 1.0, px: 1.0, py: 0.0, pz: 0.0, rx: 1.0, ry: 0.0, rz: 0.0, vx: 1.0, vy: 0.0, vz: 0.0 }
| done |> std/time:elapsed(start: s1): d1 |> std/io:print.ln("total_ns {{ d1.ns:d }}")

std/time:now(): s2 |> for(0..10000)
! each _ |> std/store:insert(e2) { t00: 1.0, t01: 0.0, t02: 0.0, t03: 0.0, t10: 0.0, t11: 1.0, t12: 0.0, t13: 0.0, t20: 0.0, t21: 0.0, t22: 1.0, t23: 0.0, t30: 0.0, t31: 0.0, t32: 0.0, t33: 1.0, px: 1.0, py: 0.0, pz: 0.0, rx: 1.0, ry: 0.0, rz: 0.0, vx: 1.0, vy: 0.0, vz: 0.0 }
| done |> std/time:elapsed(start: s2): d2 |> std/io:print.ln("total_ns {{ d2.ns:d }}")

std/time:now(): s3 |> for(0..10000)
! each _ |> std/store:insert(e3) { t00: 1.0, t01: 0.0, t02: 0.0, t03: 0.0, t10: 0.0, t11: 1.0, t12: 0.0, t13: 0.0, t20: 0.0, t21: 0.0, t22: 1.0, t23: 0.0, t30: 0.0, t31: 0.0, t32: 0.0, t33: 1.0, px: 1.0, py: 0.0, pz: 0.0, rx: 1.0, ry: 0.0, rz: 0.0, vx: 1.0, vy: 0.0, vz: 0.0 }
| done |> std/time:elapsed(start: s3): d3 |> std/io:print.ln("total_ns {{ d3.ns:d }}")

std/time:now(): s4 |> for(0..10000)
! each _ |> std/store:insert(e4) { t00: 1.0, t01: 0.0, t02: 0.0, t03: 0.0, t10: 0.0, t11: 1.0, t12: 0.0, t13: 0.0, t20: 0.0, t21: 0.0, t22: 1.0, t23: 0.0, t30: 0.0, t31: 0.0, t32: 0.0, t33: 1.0, px: 1.0, py: 0.0, pz: 0.0, rx: 1.0, ry: 0.0, rz: 0.0, vx: 1.0, vy: 0.0, vz: 0.0 }
| done |> std/time:elapsed(start: s4): d4 |> std/io:print.ln("total_ns {{ d4.ns:d }}")

std/time:now(): s5 |> for(0..10000)
! each _ |> std/store:insert(e5) { t00: 1.0, t01: 0.0, t02: 0.0, t03: 0.0, t10: 0.0, t11: 1.0, t12: 0.0, t13: 0.0, t20: 0.0, t21: 0.0, t22: 1.0, t23: 0.0, t30: 0.0, t31: 0.0, t32: 0.0, t33: 1.0, px: 1.0, py: 0.0, pz: 0.0, rx: 1.0, ry: 0.0, rz: 0.0, vx: 1.0, vy: 0.0, vz: 0.0 }
| done |> std/time:elapsed(start: s5): d5 |> std/io:print.ln("total_ns {{ d5.ns:d }}") |> std/io:print.ln("timed_iters 5")

std/store:query(w)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:query(e1)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:query(e2)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:query(e3)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:query(e4)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:query(e5)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:stored { out.v: check.sum }
