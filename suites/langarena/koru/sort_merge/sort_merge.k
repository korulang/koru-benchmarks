// sort_merge — LangArena Sort::Merge, run.js scored parameters
// (size=400000, iterations=50, warmup_iterations=10 → oracle 61757772 —
// same harness as Sort::Quick; sorted arrays agree).
//
// Faithful port of reference/crystal/main.cr Sort::Merge:
//   merge: copy arr[left..right] into temp, merge back (i over left half,
//   j over right half, k writes), then drain the left-half remainder —
//   the right-half remainder is already in place (same as reference).
//
// Faithfulness differences, stated:
// - Static i64 grids (data + arr + tbuf); reference heap-allocates i32.
// - While-loops are tail-recursive tors lowered to `while` (requires the
//   direct `-> r` produce — projection defeats the lowering).
// - msort's two recursive calls are real calls; depth ~log2(400000) ≈ 19.
// - acc i64 + explicit mod-2^32 fold (u32 &+); working state in a
//   singleton store (capture bindings end at their arm — KORU108).
// - Warmup/measured Helper.reset split modeled exactly (see sort_quick).
//
import std/io
import std/grid
import std/store

std/grid:new(data, size: 400000) { b: 0[i64] }
std/grid:new(arr, size: 400000) { v: 0[i64] }
std/grid:new(tbuf, size: 400000) { v: 0[i64] }
std/store:new(st) { acc: 0[i64], last: 42[i64] }

// mcopy — temp[i] = arr[i] for i in left..right inclusive
pub tor mcopy { i: i64, right: i64 } -> i64
mcopy = if(i <= right)
| then |> std/grid:stored { tbuf_s[@as(usize, @intCast(i))]: arr_s[@as(usize, @intCast(i))] }
    |> mcopy(i: i + 1, right): r -> r
| else -> i

std/grid:slice(arr_s) { arr.v }
std/grid:slice(tbuf_s) { tbuf.v }
std/grid:slice(data_s) { data.b }

// mrun — the merge walk: while i <= mid and j <= right, take the smaller.
// Returns the stopped cursors; k is derived (writes = i-left + j-mid-1).
pub tor mrun { i: i64, j: i64, k: i64, mid: i64, right: i64 } -> { i: i64, j: i64 }
mrun = if(i <= mid and j <= right)
| then |> if(tbuf_s[@as(usize, @intCast(i))] <= tbuf_s[@as(usize, @intCast(j))])
        | then |> std/grid:stored { arr_s[@as(usize, @intCast(k))]: tbuf_s[@as(usize, @intCast(i))] }
            |> mrun(i: i + 1, j, k: k + 1, mid, right): r -> r
        | else |> std/grid:stored { arr_s[@as(usize, @intCast(k))]: tbuf_s[@as(usize, @intCast(j))] }
            |> mrun(i, j: j + 1, k: k + 1, mid, right): r -> r
| else -> { i, j }

// mrest — drain the left-half remainder: while i <= mid, arr[k] = tbuf[i]
pub tor mrest { i: i64, k: i64, mid: i64 } -> i64
mrest = if(i <= mid)
| then |> std/grid:stored { arr_s[@as(usize, @intCast(k))]: tbuf_s[@as(usize, @intCast(i))] }
    |> mrest(i: i + 1, k: k + 1, mid): r -> r
| else -> i

// merge(left, mid, right) — copy to tbuf, merge back, drain left
pub tor merge { left: i64, mid: i64, right: i64 } -> i64
merge = mcopy(i: left, right): _
|> mrun(i: left, j: mid + 1, k: left, mid, right): m
    |> mrest(m.i, k: m.i + m.j - mid - 1, mid): _ -> 0

// msort(left, right) — recursive merge sort over arr
pub tor msort { left: i64, right: i64 } -> i64
msort = if(left < right)
| then |> msort(left, right: @divTrunc(left + right, 2)): _
    |> msort(left: @divTrunc(left + right, 2) + 1, right): _
    |> merge(left, mid: @divTrunc(left + right, 2), right): _ -> 0
| else -> 0

// prepare: fill data once via the LCG (next_int(1_000_000) per element)
for(0..400000)
! each i |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/grid:stored { data_s[@as(usize, @intCast(i))]: @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 1000000.0)) }

// warmup: 10 iterations on the continuing prepare stream. One iteration:
// sample unsorted, copy, sort, sample sorted — LCG draws interleave
// exactly like the reference run(). The body lives in an `! each` arm —
// `for`'s `| done` continuation only resumes inside a flow arm.
for(0..10)
! each it |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/store:stored { st.acc: @rem(st.acc + data_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }
    |> for(0..400000)
        ! each i |> std/grid:stored { arr_s[@as(usize, @intCast(i))]: data_s[@as(usize, @intCast(i))] }
    | done |> msort(left: 0, right: 399999): _
        |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
        |> std/store:stored { st.acc: @rem(st.acc + arr_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }

// Helper.reset — measured iterations sample a fresh stream seeded at 42
std/store:stored { st.last: 42 }

for(0..50)
! each it |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/store:stored { st.acc: @rem(st.acc + data_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }
    |> for(0..400000)
        ! each i |> std/grid:stored { arr_s[@as(usize, @intCast(i))]: data_s[@as(usize, @intCast(i))] }
    | done |> msort(left: 0, right: 399999): _
        |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
        |> std/store:stored { st.acc: @rem(st.acc + arr_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
