// Is the stride "effect" real, or an artifact of running write and rmw
// back-to-back over the same arrays? Previous sweep showed perfect
// anti-correlation with a near-constant sum, which is what interference looks
// like, not what a cache effect looks like.
//
// This binary measures ONE shape, chosen by argv, so the two never share a
// process. argv: <shape: write|rmw> <pad-index>
const std = @import("std");

const N: usize = 50000;
const PASSES: usize = 200;
const PADS = [_]usize{ 0, 8, 16, 24, 32, 40, 48, 56, 64, 96, 128, 160, 192, 224, 256, 320, 448, 576, 704, 1024, 1536, 2048 };

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

fn run(comptime PAD: usize, want_rmw: bool) f64 {
    const st = struct {
        var s: Store(PAD) = .{};
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
    const f: *const fn () void = if (want_rmw) &W.rmw else &W.write;
    var best: f64 = 1e30;
    for (0..5) |_| {
        for (0..50) |_| f();
        const t0 = std.time.nanoTimestamp();
        for (0..PASSES) |_| f();
        const p = @as(f64, @floatFromInt(std.time.nanoTimestamp() - t0)) / @as(f64, PASSES) / @as(f64, N);
        if (p < best) best = p;
    }
    std.mem.doNotOptimizeAway(&st.s);
    return best;
}

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const args = try std.process.argsAlloc(fba.allocator());
    const want_rmw = std.mem.eql(u8, args[1], "rmw");
    const idx = try std.fmt.parseInt(usize, args[2], 10);
    inline for (PADS, 0..) |P, i| {
        if (i == idx) {
            const r = run(P, want_rmw);
            std.debug.print("{d} {d} {d:.4}\n", .{ P, N * 8 + P, r });
        }
    }
}
