// heavy_compute — 1,000 entities, the 4x4 matrix inverted 100 times per
// entity per iteration, in place. One iteration = 100 passes; each pass's
// stored block computes the determinant ONCE into e.det, divides sixteen
// cofactor entries into it (690_128's factoring — one determinant expansion
// per row instead of seventeen), then copies o back over t in the SAME block,
// legal because a plural stored block's entries land in written order
// (690_126; the frame-loop copy-back shape is 690_129). Columns are f64 —
// the reference matrix is cgmath Matrix4<f32>; heavy_compute_f32.k is the
// width-faithful variant.
//
// Faithfulness differences, stated: the reference iterates rayon-parallel
// batches of 64 — ours is single-threaded. The reference follows the 100
// inversions with one transform_vector per entity (9 mul + 6 add on a vec3,
// ~0.2% of the inversion arithmetic) — this port omits it, and its store
// carries the 16 mat columns plus 17 staging columns (o00..o33, det) where
// the reference row carries the mat plus three vec3 components; staging
// columns are written every pass, the reference's vec3s are not.
//
// The matrix is 690_127/128's dense det-2 integer matrix: every intermediate
// is a small dyadic rational, so each inversion is EXACT in f32 and f64, and
// inverse-of-inverse lands back on the exact original integers. The total
// pass count (warmup 300 + timed 1000 = 1300) is even, so after the last
// pass t = M (the original, 16 entries summing to -13), o = M too (the last
// pass wrote inv(M^-1)), and det = det(M^-1) = 0.5 — the det and o terms
// make the checksum blind to nothing: a no-op run would leave o = 0 and
// det = 0 and land on -13000, not the expected -25.5 per row -> -25500.
//
// Protocol: 1000 rows inserted, 300 untimed warmup passes (= 3 iterations),
// then 1000 timed passes bracketed by std/time:now()/elapsed with
// timed_iters 10 (100 passes = one reference iteration).
//
// Spellings grounded in passing koru regression tests:
//   det column factored + reused in block   690_128_stored_block_det_column_reused_in_block
//   in-place via staging + copy-back        690_129_mat4_inverse_roundtrip_frame_loop
//   frame loop (for -> each -> query)       690_129, simple_iter.k
//   clock bind + for `| done` chain         simple_iter.k (910/2111, 430_008)
import std/io
import std/store
import std/time

std/store:new(mats, capacity: 1000) { t00: f64, t01: f64, t02: f64, t03: f64, t10: f64, t11: f64, t12: f64, t13: f64, t20: f64, t21: f64, t22: f64, t23: f64, t30: f64, t31: f64, t32: f64, t33: f64, o00: f64, o01: f64, o02: f64, o03: f64, o10: f64, o11: f64, o12: f64, o13: f64, o20: f64, o21: f64, o22: f64, o23: f64, o30: f64, o31: f64, o32: f64, o33: f64, det: f64 }
std/store:new(check) { sum: 0.0[f64] }
std/store:new(out) { v: 0.0[f64] }

std/store:watch(out)
! v x |> std/io:print.ln("checksum {{ x:f }}")

for(0..1000)
! each _ |> std/store:insert(mats) { t00: -3.0, t01: -3.0, t02: 2.0, t03: -3.0, t10: 2.0, t11: -3.0, t12: -1.0, t13: -3.0, t20: -1.0, t21: -1.0, t22: 2.0, t23: 2.0, t30: 1.0, t31: 2.0, t32: -3.0, t33: -3.0, o00: 0.0, o01: 0.0, o02: 0.0, o03: 0.0, o10: 0.0, o11: 0.0, o12: 0.0, o13: 0.0, o20: 0.0, o21: 0.0, o22: 0.0, o23: 0.0, o30: 0.0, o31: 0.0, o32: 0.0, o33: 0.0, det: 0.0 }

for(0..300)
! each _ |> std/store:query(mats)
    ! query e |> std/store:stored { e.det: e.t00 * (e.t11 * e.t22 * e.t33 - e.t11 * e.t23 * e.t32 - e.t12 * e.t21 * e.t33 + e.t12 * e.t23 * e.t31 + e.t13 * e.t21 * e.t32 - e.t13 * e.t22 * e.t31) + e.t01 * (0.0 - e.t10 * e.t22 * e.t33 + e.t10 * e.t23 * e.t32 + e.t12 * e.t20 * e.t33 - e.t12 * e.t23 * e.t30 - e.t13 * e.t20 * e.t32 + e.t13 * e.t22 * e.t30) + e.t02 * (e.t10 * e.t21 * e.t33 - e.t10 * e.t23 * e.t31 - e.t11 * e.t20 * e.t33 + e.t11 * e.t23 * e.t30 + e.t13 * e.t20 * e.t31 - e.t13 * e.t21 * e.t30) + e.t03 * (0.0 - e.t10 * e.t21 * e.t32 + e.t10 * e.t22 * e.t31 + e.t11 * e.t20 * e.t32 - e.t11 * e.t22 * e.t30 - e.t12 * e.t20 * e.t31 + e.t12 * e.t21 * e.t30) }
        |> std/store:stored { e.o00: (e.t11 * e.t22 * e.t33 - e.t11 * e.t23 * e.t32 - e.t12 * e.t21 * e.t33 + e.t12 * e.t23 * e.t31 + e.t13 * e.t21 * e.t32 - e.t13 * e.t22 * e.t31) / e.det, e.o01: (0.0 - e.t01 * e.t22 * e.t33 + e.t01 * e.t23 * e.t32 + e.t02 * e.t21 * e.t33 - e.t02 * e.t23 * e.t31 - e.t03 * e.t21 * e.t32 + e.t03 * e.t22 * e.t31) / e.det, e.o02: (e.t01 * e.t12 * e.t33 - e.t01 * e.t13 * e.t32 - e.t02 * e.t11 * e.t33 + e.t02 * e.t13 * e.t31 + e.t03 * e.t11 * e.t32 - e.t03 * e.t12 * e.t31) / e.det, e.o03: (0.0 - e.t01 * e.t12 * e.t23 + e.t01 * e.t13 * e.t22 + e.t02 * e.t11 * e.t23 - e.t02 * e.t13 * e.t21 - e.t03 * e.t11 * e.t22 + e.t03 * e.t12 * e.t21) / e.det, e.o10: (0.0 - e.t10 * e.t22 * e.t33 + e.t10 * e.t23 * e.t32 + e.t12 * e.t20 * e.t33 - e.t12 * e.t23 * e.t30 - e.t13 * e.t20 * e.t32 + e.t13 * e.t22 * e.t30) / e.det, e.o11: (e.t00 * e.t22 * e.t33 - e.t00 * e.t23 * e.t32 - e.t02 * e.t20 * e.t33 + e.t02 * e.t23 * e.t30 + e.t03 * e.t20 * e.t32 - e.t03 * e.t22 * e.t30) / e.det, e.o12: (0.0 - e.t00 * e.t12 * e.t33 + e.t00 * e.t13 * e.t32 + e.t02 * e.t10 * e.t33 - e.t02 * e.t13 * e.t30 - e.t03 * e.t10 * e.t32 + e.t03 * e.t12 * e.t30) / e.det, e.o13: (e.t00 * e.t12 * e.t23 - e.t00 * e.t13 * e.t22 - e.t02 * e.t10 * e.t23 + e.t02 * e.t13 * e.t20 + e.t03 * e.t10 * e.t22 - e.t03 * e.t12 * e.t20) / e.det, e.o20: (e.t10 * e.t21 * e.t33 - e.t10 * e.t23 * e.t31 - e.t11 * e.t20 * e.t33 + e.t11 * e.t23 * e.t30 + e.t13 * e.t20 * e.t31 - e.t13 * e.t21 * e.t30) / e.det, e.o21: (0.0 - e.t00 * e.t21 * e.t33 + e.t00 * e.t23 * e.t31 + e.t01 * e.t20 * e.t33 - e.t01 * e.t23 * e.t30 - e.t03 * e.t20 * e.t31 + e.t03 * e.t21 * e.t30) / e.det, e.o22: (e.t00 * e.t11 * e.t33 - e.t00 * e.t13 * e.t31 - e.t01 * e.t10 * e.t33 + e.t01 * e.t13 * e.t30 + e.t03 * e.t10 * e.t31 - e.t03 * e.t11 * e.t30) / e.det, e.o23: (0.0 - e.t00 * e.t11 * e.t23 + e.t00 * e.t13 * e.t21 + e.t01 * e.t10 * e.t23 - e.t01 * e.t13 * e.t20 - e.t03 * e.t10 * e.t21 + e.t03 * e.t11 * e.t20) / e.det, e.o30: (0.0 - e.t10 * e.t21 * e.t32 + e.t10 * e.t22 * e.t31 + e.t11 * e.t20 * e.t32 - e.t11 * e.t22 * e.t30 - e.t12 * e.t20 * e.t31 + e.t12 * e.t21 * e.t30) / e.det, e.o31: (e.t00 * e.t21 * e.t32 - e.t00 * e.t22 * e.t31 - e.t01 * e.t20 * e.t32 + e.t01 * e.t22 * e.t30 + e.t02 * e.t20 * e.t31 - e.t02 * e.t21 * e.t30) / e.det, e.o32: (0.0 - e.t00 * e.t11 * e.t32 + e.t00 * e.t12 * e.t31 + e.t01 * e.t10 * e.t32 - e.t01 * e.t12 * e.t30 - e.t02 * e.t10 * e.t31 + e.t02 * e.t11 * e.t30) / e.det, e.o33: (e.t00 * e.t11 * e.t22 - e.t00 * e.t12 * e.t21 - e.t01 * e.t10 * e.t22 + e.t01 * e.t12 * e.t20 + e.t02 * e.t10 * e.t21 - e.t02 * e.t11 * e.t20) / e.det }
        |> std/store:stored { e.t00: e.o00, e.t01: e.o01, e.t02: e.o02, e.t03: e.o03, e.t10: e.o10, e.t11: e.o11, e.t12: e.o12, e.t13: e.o13, e.t20: e.o20, e.t21: e.o21, e.t22: e.o22, e.t23: e.o23, e.t30: e.o30, e.t31: e.o31, e.t32: e.o32, e.t33: e.o33 }

std/time:now(): start |> for(0..1000)
! each _ |> std/store:query(mats)
    ! query e |> std/store:stored { e.det: e.t00 * (e.t11 * e.t22 * e.t33 - e.t11 * e.t23 * e.t32 - e.t12 * e.t21 * e.t33 + e.t12 * e.t23 * e.t31 + e.t13 * e.t21 * e.t32 - e.t13 * e.t22 * e.t31) + e.t01 * (0.0 - e.t10 * e.t22 * e.t33 + e.t10 * e.t23 * e.t32 + e.t12 * e.t20 * e.t33 - e.t12 * e.t23 * e.t30 - e.t13 * e.t20 * e.t32 + e.t13 * e.t22 * e.t30) + e.t02 * (e.t10 * e.t21 * e.t33 - e.t10 * e.t23 * e.t31 - e.t11 * e.t20 * e.t33 + e.t11 * e.t23 * e.t30 + e.t13 * e.t20 * e.t31 - e.t13 * e.t21 * e.t30) + e.t03 * (0.0 - e.t10 * e.t21 * e.t32 + e.t10 * e.t22 * e.t31 + e.t11 * e.t20 * e.t32 - e.t11 * e.t22 * e.t30 - e.t12 * e.t20 * e.t31 + e.t12 * e.t21 * e.t30) }
        |> std/store:stored { e.o00: (e.t11 * e.t22 * e.t33 - e.t11 * e.t23 * e.t32 - e.t12 * e.t21 * e.t33 + e.t12 * e.t23 * e.t31 + e.t13 * e.t21 * e.t32 - e.t13 * e.t22 * e.t31) / e.det, e.o01: (0.0 - e.t01 * e.t22 * e.t33 + e.t01 * e.t23 * e.t32 + e.t02 * e.t21 * e.t33 - e.t02 * e.t23 * e.t31 - e.t03 * e.t21 * e.t32 + e.t03 * e.t22 * e.t31) / e.det, e.o02: (e.t01 * e.t12 * e.t33 - e.t01 * e.t13 * e.t32 - e.t02 * e.t11 * e.t33 + e.t02 * e.t13 * e.t31 + e.t03 * e.t11 * e.t32 - e.t03 * e.t12 * e.t31) / e.det, e.o03: (0.0 - e.t01 * e.t12 * e.t23 + e.t01 * e.t13 * e.t22 + e.t02 * e.t11 * e.t23 - e.t02 * e.t13 * e.t21 - e.t03 * e.t11 * e.t22 + e.t03 * e.t12 * e.t21) / e.det, e.o10: (0.0 - e.t10 * e.t22 * e.t33 + e.t10 * e.t23 * e.t32 + e.t12 * e.t20 * e.t33 - e.t12 * e.t23 * e.t30 - e.t13 * e.t20 * e.t32 + e.t13 * e.t22 * e.t30) / e.det, e.o11: (e.t00 * e.t22 * e.t33 - e.t00 * e.t23 * e.t32 - e.t02 * e.t20 * e.t33 + e.t02 * e.t23 * e.t30 + e.t03 * e.t20 * e.t32 - e.t03 * e.t22 * e.t30) / e.det, e.o12: (0.0 - e.t00 * e.t12 * e.t33 + e.t00 * e.t13 * e.t32 + e.t02 * e.t10 * e.t33 - e.t02 * e.t13 * e.t30 - e.t03 * e.t10 * e.t32 + e.t03 * e.t12 * e.t30) / e.det, e.o13: (e.t00 * e.t12 * e.t23 - e.t00 * e.t13 * e.t22 - e.t02 * e.t10 * e.t23 + e.t02 * e.t13 * e.t20 + e.t03 * e.t10 * e.t22 - e.t03 * e.t12 * e.t20) / e.det, e.o20: (e.t10 * e.t21 * e.t33 - e.t10 * e.t23 * e.t31 - e.t11 * e.t20 * e.t33 + e.t11 * e.t23 * e.t30 + e.t13 * e.t20 * e.t31 - e.t13 * e.t21 * e.t30) / e.det, e.o21: (0.0 - e.t00 * e.t21 * e.t33 + e.t00 * e.t23 * e.t31 + e.t01 * e.t20 * e.t33 - e.t01 * e.t23 * e.t30 - e.t03 * e.t20 * e.t31 + e.t03 * e.t21 * e.t30) / e.det, e.o22: (e.t00 * e.t11 * e.t33 - e.t00 * e.t13 * e.t31 - e.t01 * e.t10 * e.t33 + e.t01 * e.t13 * e.t30 + e.t03 * e.t10 * e.t31 - e.t03 * e.t11 * e.t30) / e.det, e.o23: (0.0 - e.t00 * e.t11 * e.t23 + e.t00 * e.t13 * e.t21 + e.t01 * e.t10 * e.t23 - e.t01 * e.t13 * e.t20 - e.t03 * e.t10 * e.t21 + e.t03 * e.t11 * e.t20) / e.det, e.o30: (0.0 - e.t10 * e.t21 * e.t32 + e.t10 * e.t22 * e.t31 + e.t11 * e.t20 * e.t32 - e.t11 * e.t22 * e.t30 - e.t12 * e.t20 * e.t31 + e.t12 * e.t21 * e.t30) / e.det, e.o31: (e.t00 * e.t21 * e.t32 - e.t00 * e.t22 * e.t31 - e.t01 * e.t20 * e.t32 + e.t01 * e.t22 * e.t30 + e.t02 * e.t20 * e.t31 - e.t02 * e.t21 * e.t30) / e.det, e.o32: (0.0 - e.t00 * e.t11 * e.t32 + e.t00 * e.t12 * e.t31 + e.t01 * e.t10 * e.t32 - e.t01 * e.t12 * e.t30 - e.t02 * e.t10 * e.t31 + e.t02 * e.t11 * e.t30) / e.det, e.o33: (e.t00 * e.t11 * e.t22 - e.t00 * e.t12 * e.t21 - e.t01 * e.t10 * e.t22 + e.t01 * e.t12 * e.t20 + e.t02 * e.t10 * e.t21 - e.t02 * e.t11 * e.t20) / e.det }
        |> std/store:stored { e.t00: e.o00, e.t01: e.o01, e.t02: e.o02, e.t03: e.o03, e.t10: e.o10, e.t11: e.o11, e.t12: e.o12, e.t13: e.o13, e.t20: e.o20, e.t21: e.o21, e.t22: e.o22, e.t23: e.o23, e.t30: e.o30, e.t31: e.o31, e.t32: e.o32, e.t33: e.o33 }
| done |> std/time:elapsed(start): d |> std/io:print.ln("total_ns {{ d.ns:d }}") |> std/io:print.ln("timed_iters 10")

std/store:query(mats)
! query e |> std/store:stored { check.sum: check.sum + e.t00 + e.t01 + e.t02 + e.t03 + e.t10 + e.t11 + e.t12 + e.t13 + e.t20 + e.t21 + e.t22 + e.t23 + e.t30 + e.t31 + e.t32 + e.t33 + e.o00 + e.o01 + e.o02 + e.o03 + e.o10 + e.o11 + e.o12 + e.o13 + e.o20 + e.o21 + e.o22 + e.o23 + e.o30 + e.o31 + e.o32 + e.o33 + e.det }

std/store:stored { out.v: check.sum }
