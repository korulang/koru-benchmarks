// The store allocates every column of a store contiguously in one struct, so
// column i sits exactly `rows * width` bytes from column i-1. Does that stride
// relationship cost anything, and does padding it apart recover it?
const std = @import("std");

const N: usize = 50000;
const PASSES: usize = 300;

fn Store(comptime PAD: usize) type {
    return extern struct {
        len: usize = N,
        p1: [N]f64 = undefined,
        _a: [PAD]u8 = undefined,
        p2: [N]f64 = undefined,
        _b: [PAD]u8 = undefined,
        p3: [N]f64 = undefined,
        _c: [PAD]u8 = undefined,
        v1: [N]f64 = undefined,
        _d: [PAD]u8 = undefined,
        v2: [N]f64 = undefined,
        _e: [PAD]u8 = undefined,
        v3: [N]f64 = undefined,
    };
}

fn run(comptime PAD: usize) void {
    const S = Store(PAD);
    const st = struct {
        var s: S = .{};
    };
    @memset(&st.s.p1, 0.0);
    @memset(&st.s.p2, 0.0);
    @memset(&st.s.p3, 0.0);
    @memset(&st.s.v1, 1.0);
    @memset(&st.s.v2, 1.0);
    @memset(&st.s.v3, 1.0);

    const W = struct {
        fn write() void {
            for (0..st.s.len) |i| {
                st.s.p1[i] = 1.0;
                st.s.p2[i] = 1.0;
                st.s.p3[i] = 1.0;
            }
        }
        fn rmw() void {
            for (0..st.s.len) |i| {
                st.s.p1[i] = st.s.p1[i] + st.s.v1[i];
                st.s.p2[i] = st.s.p2[i] + st.s.v2[i];
                st.s.p3[i] = st.s.p3[i] + st.s.v3[i];
            }
        }
    };

    var best_w: f64 = 1e30;
    var best_r: f64 = 1e30;
    for (0..5) |_| {
        for (0..50) |_| W.write();
        var t0 = std.time.nanoTimestamp();
        for (0..PASSES) |_| W.write();
        var per = @as(f64, @floatFromInt(std.time.nanoTimestamp() - t0)) / @as(f64, PASSES) / @as(f64, N);
        if (per < best_w) best_w = per;

        for (0..50) |_| W.rmw();
        t0 = std.time.nanoTimestamp();
        for (0..PASSES) |_| W.rmw();
        per = @as(f64, @floatFromInt(std.time.nanoTimestamp() - t0)) / @as(f64, PASSES) / @as(f64, N);
        if (per < best_r) best_r = per;
    }
    const stride = @sizeOf([N]f64) + PAD;
    std.debug.print("pad {d:>6} B   column stride {d:>7} B   write {d:>6.3}   rmw {d:>6.3} ns/row\n",
        .{ PAD, stride, best_w, best_r });
    std.mem.doNotOptimizeAway(&st.s);
}

pub fn main() void {
    std.debug.print("N={d} rows, 3 columns written, f64. best-of-5 windows.\n\n", .{N});
    run(0);
    run(64);
    run(128);
    run(256);
    run(512);
    run(1024);
    run(2048);
    run(4096);
}
