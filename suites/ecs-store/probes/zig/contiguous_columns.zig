// Last hypothesis: koru's columns and its MUTABLE `len` live in one global
// struct, and the sweep loop bound is `store.len`. If LLVM cannot prove a
// store to a column does not alias `len`, it must reload the bound every
// iteration and cannot vectorise freely. Memory-bound shapes (rmw) hide that;
// a short write-only loop cannot.
const std = @import("std");

const N: usize = 50000;
const PASSES: usize = 1000;

// Shaped exactly like koru's emitted __koru_store_<s>: len beside the columns.
const Store = struct {
    len: usize = 0,
    p1: [N]f64 = undefined,
    p2: [N]f64 = undefined,
    p3: [N]f64 = undefined,
    v1: [N]f64 = undefined,
    v2: [N]f64 = undefined,
    v3: [N]f64 = undefined,
};
var s: Store = .{};

fn structWrite() void {
    for (0..s.len) |i| {
        s.p1[i] = 1.0;
        s.p2[i] = 1.0;
        s.p3[i] = 1.0;
    }
}

fn structWriteHoisted() void {
    const n = s.len; // the whole proposed fix
    for (0..n) |i| {
        s.p1[i] = 1.0;
        s.p2[i] = 1.0;
        s.p3[i] = 1.0;
    }
}

fn structRmw() void {
    for (0..s.len) |i| {
        s.p1[i] = s.p1[i] + s.v1[i];
        s.p2[i] = s.p2[i] + s.v2[i];
        s.p3[i] = s.p3[i] + s.v3[i];
    }
}

fn structRmwHoisted() void {
    const n = s.len;
    for (0..n) |i| {
        s.p1[i] = s.p1[i] + s.v1[i];
        s.p2[i] = s.p2[i] + s.v2[i];
        s.p3[i] = s.p3[i] + s.v3[i];
    }
}

fn bench(comptime name: []const u8, comptime f: fn () void) void {
    for (0..100) |_| f();
    const t0 = std.time.nanoTimestamp();
    for (0..PASSES) |_| f();
    const dt = std.time.nanoTimestamp() - t0;
    const per: f64 = @as(f64, @floatFromInt(dt)) / @as(f64, PASSES);
    std.debug.print("{s:<28} {d:>9.0} ns/pass   {d:>6.3} ns/row\n", .{ name, per, per / @as(f64, N) });
}

pub fn main() void {
    s.len = N;
    @memset(&s.p1, 0.0);
    @memset(&s.p2, 0.0);
    @memset(&s.p3, 0.0);
    @memset(&s.v1, 1.0);
    @memset(&s.v2, 1.0);
    @memset(&s.v3, 1.0);
    bench("struct write  (bound=s.len)", structWrite);
    bench("struct write  (bound hoisted)", structWriteHoisted);
    bench("struct rmw    (bound=s.len)", structRmw);
    bench("struct rmw    (bound hoisted)", structRmwHoisted);
    std.mem.doNotOptimizeAway(&s);
}
