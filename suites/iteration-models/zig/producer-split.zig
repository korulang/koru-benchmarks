const std = @import("std");
var g: usize = 1;
const Evens = struct {
    i: usize = 0,
    n: usize,
    fn next(self: *Evens) ?usize {
        while (self.i < self.n) {
            self.i += 1;
            if (@rem(self.i, 2) == 0) return self.i;
        }
        return null;
    }
};
fn task(n: usize) i64 {
    var acc: i64 = 0;
    var it = Evens{ .n = n };
    while (it.next()) |v| acc += @as(i64, @intCast(v)) * 3;
    return acc;
}
pub fn main() void {
    g = 10_000_000 + std.os.argv.len;
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
