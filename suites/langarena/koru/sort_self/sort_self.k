// sort_self — LangArena Sort::Self, run.js scored parameters
// (size=400000, iterations=50, warmup_iterations=10 -> oracle 61757772).
//
// Faithful port of reference/crystal/main.cr Sort::Self: same
// SortBenchmark harness as Sort::Quick/Merge (LCG data, warmup/measured
// reset split — see sort_quick.k's comment), but `test` is the
// language's own sort: `arr = @data.dup; arr.sort!`.
//
// Koru's own sort is std/array:sort — an [expand] template lowering to
// Zig std.mem.sort on a slice. Its sort target here is the arr grid's
// backing array, spelled by emitted name (main_module.__koru_grid_arr.v)
// — white-box coupling to emission internals, stated, not hidden: koru
// has no value-level slice spelling for grid storage.
//
// Note: `arr.dup` is the grid-to-grid copy loop (data is never sorted
// in the reference; the copy is). Sample order matches: pre-sort draw,
// copy+sort, post-sort draw.
//
import std/io
import std/grid
import std/store
import std/array

std/grid:new(data, size: 400000) { b: 0[i64] }
std/grid:new(arr, size: 400000) { v: 0[i64] }
std/store:new(st) { acc: 0[i64], last: 42[i64] }

// prepare: data[i] = next_int(1_000_000) — LCG last = (last*3877+29573)
// mod 139968 seeded 42; value = floor(last / 139968.0 * max)
for(0..400000)
! each i |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/grid:stored { data[i].b: @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 1000000.0)) }

// warmup — 10 iterations on the continuing stream
for(0..10)
! each it |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/store:stored { st.acc: @rem(st.acc + data[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))].b, 4294967296) }
    |> for(0..400000)
        ! each i |> std/grid:stored { arr[i].v: data[i].b }
    | done |> std/array:sort(main_module.__koru_grid_arr.v[0..400000]): _
        |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
        |> std/store:stored { st.acc: @rem(st.acc + arr[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))].v, 4294967296) }

// Helper.reset — measured iterations sample a fresh stream seeded at 42
std/store:stored { st.last: 42 }

for(0..50)
! each it |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/store:stored { st.acc: @rem(st.acc + data[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))].b, 4294967296) }
    |> for(0..400000)
        ! each i |> std/grid:stored { arr[i].v: data[i].b }
    | done |> std/array:sort(main_module.__koru_grid_arr.v[0..400000]): _
        |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
        |> std/store:stored { st.acc: @rem(st.acc + arr[@as(usize, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * 400000.0))))].v, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
