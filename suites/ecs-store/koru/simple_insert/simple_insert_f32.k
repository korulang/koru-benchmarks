// simple_insert_f32 — the WIDTH-FAITHFUL variant: the reference components
// are f32 (cgmath Matrix4<f32>, Vector3<f32>), and so are these columns.
// Identical protocol, workload and checksum arithmetic to simple_insert.k;
// only the six wide stores' column type differs. The checksum accumulator
// stays f64 — an f32 column read into f64 arithmetic widens losslessly
// (the narrowing direction is the refusal pinned at koru 690_160). Every
// partial checksum is an integer below 2^24, so the sum is exact in either
// width.
import std/io
import std/store
import std/time

std/store:new(w, capacity: 10000) { t00: f32, t01: f32, t02: f32, t03: f32, t10: f32, t11: f32, t12: f32, t13: f32, t20: f32, t21: f32, t22: f32, t23: f32, t30: f32, t31: f32, t32: f32, t33: f32, px: f32, py: f32, pz: f32, rx: f32, ry: f32, rz: f32, vx: f32, vy: f32, vz: f32 }
std/store:new(e1, capacity: 10000) { t00: f32, t01: f32, t02: f32, t03: f32, t10: f32, t11: f32, t12: f32, t13: f32, t20: f32, t21: f32, t22: f32, t23: f32, t30: f32, t31: f32, t32: f32, t33: f32, px: f32, py: f32, pz: f32, rx: f32, ry: f32, rz: f32, vx: f32, vy: f32, vz: f32 }
std/store:new(e2, capacity: 10000) { t00: f32, t01: f32, t02: f32, t03: f32, t10: f32, t11: f32, t12: f32, t13: f32, t20: f32, t21: f32, t22: f32, t23: f32, t30: f32, t31: f32, t32: f32, t33: f32, px: f32, py: f32, pz: f32, rx: f32, ry: f32, rz: f32, vx: f32, vy: f32, vz: f32 }
std/store:new(e3, capacity: 10000) { t00: f32, t01: f32, t02: f32, t03: f32, t10: f32, t11: f32, t12: f32, t13: f32, t20: f32, t21: f32, t22: f32, t23: f32, t30: f32, t31: f32, t32: f32, t33: f32, px: f32, py: f32, pz: f32, rx: f32, ry: f32, rz: f32, vx: f32, vy: f32, vz: f32 }
std/store:new(e4, capacity: 10000) { t00: f32, t01: f32, t02: f32, t03: f32, t10: f32, t11: f32, t12: f32, t13: f32, t20: f32, t21: f32, t22: f32, t23: f32, t30: f32, t31: f32, t32: f32, t33: f32, px: f32, py: f32, pz: f32, rx: f32, ry: f32, rz: f32, vx: f32, vy: f32, vz: f32 }
std/store:new(e5, capacity: 10000) { t00: f32, t01: f32, t02: f32, t03: f32, t10: f32, t11: f32, t12: f32, t13: f32, t20: f32, t21: f32, t22: f32, t23: f32, t30: f32, t31: f32, t32: f32, t33: f32, px: f32, py: f32, pz: f32, rx: f32, ry: f32, rz: f32, vx: f32, vy: f32, vz: f32 }
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

std/store:sweep(w)
! sweep e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:sweep(e1)
! sweep e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:sweep(e2)
! sweep e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:sweep(e3)
! sweep e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:sweep(e4)
! sweep e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:sweep(e5)
! sweep e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.px + e.py + e.pz + e.rx + e.ry + e.rz + e.vx + e.vy + e.vz }

std/store:stored { out.v: check.sum }
