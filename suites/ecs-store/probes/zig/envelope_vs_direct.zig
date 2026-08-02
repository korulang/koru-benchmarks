// Reproduce std/store's write envelope EXACTLY as koru emits it, and ask why
// LLVM optimizes it well for a computed value and badly for a constant.
//
// The emitted shape (from output_emitted.zig) is: one `envwrite` proc taking
// a row, a runtime `field` selector and SIX value slots, dispatched by a
// switch; the arm body calls it once per written column with the other five
// slots passed as 0.0.
const std = @import("std");

const N: usize = 50000;
const PASSES: usize = 1000;

var p1: [N]f64 = undefined;
var p2: [N]f64 = undefined;
var p3: [N]f64 = undefined;
var v1: [N]f64 = undefined;
var v2: [N]f64 = undefined;
var v3: [N]f64 = undefined;

// verbatim shape of __store_envwrite_ents
inline fn envwrite(row: i64, field: i64, value_0: f64, value_1: f64, value_2: f64,
    value_3: f64, value_4: f64, value_5: f64) void {
    const r = @as(usize, @intCast(row));
    switch (field) {
        0 => p1[r] = value_0,
        1 => p2[r] = value_1,
        2 => p3[r] = value_2,
        3 => v1[r] = value_3,
        4 => v2[r] = value_4,
        5 => v3[r] = value_5,
        else => unreachable,
    }
}

fn directConst() void {
    for (0..N) |i| {
        p1[i] = 1.0;
        p2[i] = 1.0;
        p3[i] = 1.0;
    }
}

fn directRmw() void {
    for (0..N) |i| {
        p1[i] = p1[i] + v1[i];
        p2[i] = p2[i] + v2[i];
        p3[i] = p3[i] + v3[i];
    }
}

fn envConst() void {
    for (0..N) |i| {
        const r = @as(i64, @intCast(i));
        envwrite(r, 0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        envwrite(r, 1, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0);
        envwrite(r, 2, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0);
    }
}

fn envRmw() void {
    for (0..N) |i| {
        const r = @as(i64, @intCast(i));
        envwrite(r, 0, p1[i] + v1[i], 0.0, 0.0, 0.0, 0.0, 0.0);
        envwrite(r, 1, 0.0, p2[i] + v2[i], 0.0, 0.0, 0.0, 0.0);
        envwrite(r, 2, 0.0, 0.0, p3[i] + v3[i], 0.0, 0.0, 0.0);
    }
}

fn bench(comptime name: []const u8, comptime f: fn () void) void {
    for (0..100) |_| f();
    const t0 = std.time.nanoTimestamp();
    for (0..PASSES) |_| f();
    const dt = std.time.nanoTimestamp() - t0;
    const per: f64 = @as(f64, @floatFromInt(dt)) / @as(f64, PASSES);
    std.debug.print("{s:<24} {d:>9.0} ns/pass   {d:>6.3} ns/row\n", .{ name, per, per / @as(f64, N) });
}

pub fn main() void {
    @memset(&p1, 0.0);
    @memset(&p2, 0.0);
    @memset(&p3, 0.0);
    @memset(&v1, 1.0);
    @memset(&v2, 1.0);
    @memset(&v3, 1.0);
    bench("direct  const", directConst);
    bench("envelope const", envConst);
    bench("direct  rmw", directRmw);
    bench("envelope rmw", envRmw);
    std.mem.doNotOptimizeAway(&p1);
    std.mem.doNotOptimizeAway(&p2);
    std.mem.doNotOptimizeAway(&p3);
}
