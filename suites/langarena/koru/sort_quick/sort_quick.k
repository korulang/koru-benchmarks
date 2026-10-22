// sort_quick — LangArena Sort::Quick, run.js scored parameters
// (size=400000, iterations=50, warmup_iterations=10 → oracle 61757772).
//
// Faithful port of reference/crystal/main.cr Sort::Quick:
//   prepare:  data[i] = next_int(1_000_000) — LCG last = (last*3877+29573)
//             mod 139968 seeded 42; value = floor(last / 139968.0 * max)
//   run:      acc += data[next_int(size)]; sort a copy with Hoare-partition
//             quicksort (mid pivot); acc += sorted[next_int(size)]
//   checksum: result_val is the raw u32 accumulator (no DJB2)
//
// Harness detail that matters (crystal main.cr:172-177): Helper.reset
// runs before prepare AND again between warmup and run_all — warmup
// iterations sample with the continuing prepare stream, measured
// iterations sample a fresh stream seeded at 42. The kernel therefore
// runs 10 warmup iterations, resets st.last, then 50 measured.
//
// Faithfulness differences, stated:
// - Static i64 grids (data + arr scratch); the reference heap-allocates
//   i32 and memcpy's per run. Same values.
// - While-loops are tail-recursive tors — the emitter lowers tail
//   self-calls to while loops, but ONLY for a direct `-> r` return: a
//   field-projection produce (`-> { r.i, r.j }`) emits a real call and
//   pstep would recurse ~200K deep (stack overflow at scored size).
// - The swap temp is a store field (single-threaded recursion).
// - acc is i64 with an explicit mod-2^32 fold (u32 &+).
// - Working state lives in a singleton store: `! as g` capture bindings
//   end with their arm and do not reach nested `! each` bodies (KORU108).
//
import std/io
import std/grid
import std/store

std/grid:new(data, size: 400000) { b: 0[i64] }
std/grid:new(arr, size: 400000) { v: 0[i64] }
std/grid:slice(arr_s) { arr.v }
std/grid:slice(data_s) { data.b }

pub tor idv { v: i64 } -> i64
idv = if(0 == 0)
| then -> v
| else -> v

std/store:new(st) { acc: 0[i64], last: 42[i64], tmp: 0[i64] }

// advi/advj — the partition index walks: advance i while arr[i] < pivot,
// retreat j while arr[j] > pivot. Tail-recursive; lowers to while loops.
pub tor advi { i: i64, pivot: i64 } -> i64
advi = if(arr_s[@as(usize, @intCast(i))] < pivot)
| then |> advi(i: i + 1, pivot): r -> r
| else -> i

pub tor advj { j: i64, pivot: i64 } -> i64
advj = if(arr_s[@as(usize, @intCast(j))] > pivot)
| then |> advj(j: j - 1, pivot): r -> r
| else -> j

// pstep — one Hoare-partition step: walk indices to their stop, swap if
// still ordered, recurse. Returns the final crossed (i, j).
pub tor pstep { i: i64, j: i64, pivot: i64 } -> { i: i64, j: i64 }
pstep = if(i <= j)
| then |> advi(i, pivot): i2 |> advj(j, pivot): j2
    |> if(i2 <= j2)
        | then |> idv(v: arr_s[@as(usize, @intCast(i2))]): t
            |> std/grid:stored { arr_s[@as(usize, @intCast(i2))]: arr_s[@as(usize, @intCast(j2))] }
            |> std/grid:stored { arr_s[@as(usize, @intCast(j2))]: t }
            |> pstep(i: i2 + 1, j: j2 - 1, pivot): r -> r
        | else -> { i: i2, j: j2 }
| else -> { i, j }

// qsort — recursive quicksort over arr[lo..hi]; returns 0 (work is the
// grid writes). Crystal's j may reach -1 (signed); identical bound checks
// make the recursion equivalent.
pub tor qsort { lo: i64, hi: i64 } -> i64
qsort = if(lo < hi)
| then |> pstep(i: lo, j: hi, pivot: arr_s[@as(usize, @intCast(@divTrunc(hi + lo, 2)))]): p
    |> if(p.j > lo)
        | then |> qsort(lo, hi: p.j): _
            |> if(p.i < hi)
                | then |> qsort(lo: p.i, hi): _ -> 0
                | else -> 0
        | else |> if(p.i < hi)
            | then |> qsort(lo: p.i, hi): _ -> 0
            | else -> 0
| else -> 0

// prepare: fill data once via the LCG (next_int(1_000_000) per element)
for(0..400000)
! each i |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/grid:stored { data_s[@as(usize, @intCast(i))]: @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 1000000.0)) }

// one iteration: sample unsorted, copy, sort, sample sorted — LCG draws
// interleave exactly like the reference run(). Written as an `! each` arm
// body: `for`'s `| done` continuation only resumes inside a flow arm —
// a tor body's `|` continuations belong to the tor.
for(0..10)
! each it |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/store:stored { st.acc: @rem(st.acc + data_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }
    |> for(0..400000)
        ! each i |> std/grid:stored { arr_s[@as(usize, @intCast(i))]: data_s[@as(usize, @intCast(i))] }
    | done |> qsort(lo: 0, hi: 399999): _
        |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
        |> std/store:stored { st.acc: @rem(st.acc + arr_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }

// Helper.reset — measured iterations sample a fresh stream seeded at 42
std/store:stored { st.last: 42 }

for(0..50)
! each it |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/store:stored { st.acc: @rem(st.acc + data_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }
    |> for(0..400000)
        ! each i |> std/grid:stored { arr_s[@as(usize, @intCast(i))]: data_s[@as(usize, @intCast(i))] }
    | done |> qsort(lo: 0, hi: 399999): _
        |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
        |> std/store:stored { st.acc: @rem(st.acc + arr_s[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))], 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
