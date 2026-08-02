// Decompose the standing-rule row tax. rf_stripe_1 and rf_sweeps_1 run the
// SAME rule body (p1 += vx) over the same 10k-row 9-column store and sit
// 6.31x apart. The emitted difference is three things at once:
//
//   1. loop form   — rule path uses `while (i < s.len)` with a len re-read and
//                    a conditional increment (row-removal tolerance); query
//                    path uses `for (0..s.len)`.
//   2. projection  — rule path loads ALL NINE columns per row; query path
//                    binds only the columns the arm actually names (2 here).
//   3. handle      — rule path resolves __koru_handle_of(row) per row.
//
// Which one is the tax? One shape per process so the variants cannot interfere.
// argv: <variant 0..4>
const std = @import("std");

const N: usize = 10000;
const PASSES: usize = 1000;

const Store = struct {
    vx: [N]f64 = undefined,
    p1: [N]f64 = undefined,
    p2: [N]f64 = undefined,
    p3: [N]f64 = undefined,
    p4: [N]f64 = undefined,
    p5: [N]f64 = undefined,
    p6: [N]f64 = undefined,
    p7: [N]f64 = undefined,
    p8: [N]f64 = undefined,
    len: usize = N,
    row_hslot: [N]usize = undefined,
    hslot_gen: [N]u32 = undefined,
};
var s: Store = .{};

fn handleOf(r: usize) i64 {
    return @as(i64, @intCast(s.row_hslot[r])) | (@as(i64, s.hslot_gen[r]) << 32);
}

// A — query path: for loop, projected read set (vx, p1)
fn forProjected() void {
    for (0..s.len) |i| {
        const vx = s.vx[i];
        const p1 = s.p1[i];
        s.p1[i] = p1 + vx;
    }
}

// B — loop form only: while + len re-read + conditional increment
fn whileProjected() void {
    var i: usize = 0;
    while (i < s.len) {
        const before = s.len;
        const vx = s.vx[i];
        const p1 = s.p1[i];
        s.p1[i] = p1 + vx;
        if (s.len >= before) i += 1;
    }
}

// C — projection only: for loop, but load all nine columns
fn forFullRow() void {
    for (0..s.len) |i| {
        const vx = s.vx[i];
        const p1 = s.p1[i];
        const p2 = s.p2[i];
        const p3 = s.p3[i];
        const p4 = s.p4[i];
        const p5 = s.p5[i];
        const p6 = s.p6[i];
        const p7 = s.p7[i];
        const p8 = s.p8[i];
        std.mem.doNotOptimizeAway(.{ p2, p3, p4, p5, p6, p7, p8 });
        s.p1[i] = p1 + vx;
    }
}

// D — the full rule path: while + full row + handle resolve
fn whileFullRowHandle() void {
    var i: usize = 0;
    while (i < s.len) {
        const before = s.len;
        const vx = s.vx[i];
        const p1 = s.p1[i];
        const p2 = s.p2[i];
        const p3 = s.p3[i];
        const p4 = s.p4[i];
        const p5 = s.p5[i];
        const p6 = s.p6[i];
        const p7 = s.p7[i];
        const p8 = s.p8[i];
        const h = handleOf(i);
        std.mem.doNotOptimizeAway(.{ p2, p3, p4, p5, p6, p7, p8, h });
        s.p1[i] = p1 + vx;
        if (s.len >= before) i += 1;
    }
}

// E — for loop + full row + handle (isolates the loop form against D)
fn forFullRowHandle() void {
    for (0..s.len) |i| {
        const vx = s.vx[i];
        const p1 = s.p1[i];
        const p2 = s.p2[i];
        const p3 = s.p3[i];
        const p4 = s.p4[i];
        const p5 = s.p5[i];
        const p6 = s.p6[i];
        const p7 = s.p7[i];
        const p8 = s.p8[i];
        const h = handleOf(i);
        std.mem.doNotOptimizeAway(.{ p2, p3, p4, p5, p6, p7, p8, h });
        s.p1[i] = p1 + vx;
    }
}

const NAMES = [_][]const u8{
    "A for + projected  (query path)",
    "B while + projected",
    "C for + full row",
    "D while + full row + handle (rule path)",
    "E for + full row + handle",
};

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const args = try std.process.argsAlloc(fba.allocator());
    const v = try std.fmt.parseInt(usize, args[1], 10);
    @memset(&s.vx, 1.0);
    @memset(&s.p1, 0.0);
    @memset(&s.p2, 0.0);
    @memset(&s.p3, 0.0);
    @memset(&s.p4, 0.0);
    @memset(&s.p5, 0.0);
    @memset(&s.p6, 0.0);
    @memset(&s.p7, 0.0);
    @memset(&s.p8, 0.0);
    @memset(&s.row_hslot, 0);
    @memset(&s.hslot_gen, 0);
    const fns = [_]*const fn () void{ &forProjected, &whileProjected, &forFullRow, &whileFullRowHandle, &forFullRowHandle };
    const f = fns[v];
    var best: f64 = 1e30;
    for (0..5) |_| {
        for (0..100) |_| f();
        const t0 = std.time.nanoTimestamp();
        for (0..PASSES) |_| f();
        const p = @as(f64, @floatFromInt(std.time.nanoTimestamp() - t0)) / @as(f64, PASSES);
        if (p < best) best = p;
    }
    std.debug.print("{s:<42} {d:>9.0} ns/pass\n", .{ NAMES[v], best });
    std.mem.doNotOptimizeAway(&s);
}
