const std = @import("std");
var data: [10_000_100]usize = undefined;
var g: usize = 1;
fn task(n: usize) i64 {
    var acc: i64 = 0;
    for (data[0..n]) |v| {
        if (@rem(v, 2) == 0) acc += @as(i64, @intCast(v)) * 3;
    }
    return acc;
}
pub fn main() void {
    g = 10_000_000 + std.os.argv.len;
    for (0..g) |i| data[i] = i + 1;
    var b: u64 = std.math.maxInt(u64);
    var c: i64 = 0;
    for (0..7) |_| {
        const t = std.time.nanoTimestamp();
        c = task(g);
        const e = @as(u64, @intCast(std.time.nanoTimestamp() - t));
        if (e < b) b = e;
    }
    std.debug.print("RESULT {d} {d:.6}\n", .{ c, @as(f64, @floatFromInt(b)) / 1e6 });
}
