// Baseline: Zig std.json.parseFromSlice into std.json.Value — FULL-TREE
// category. This does strictly MORE work than the Koru recognizer (allocates
// and builds the value tree); it is here as a category-labeled reference,
// never a same-lane comparison. Same protocol: argv doc, 3s timed passes.
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    if (args.len < 2) {
        std.debug.print("usage: zig_tree <doc.json>\n", .{});
        return error.Usage;
    }
    const doc = try std.fs.cwd().readFileAlloc(alloc, args[1], 64 * 1024 * 1024);

    const start = std.time.nanoTimestamp();
    const deadline = start + 3 * 1_000_000_000;
    var passes: i64 = 0;
    var sink: usize = 0;
    while (std.time.nanoTimestamp() < deadline) {
        const parsed = try std.json.parseFromSlice(std.json.Value, alloc, doc, .{});
        sink +%= parsed.value.object.count();
        parsed.deinit();
        passes += 1;
    }
    const elapsed: f64 = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1e9;
    std.debug.print("passes={d} seconds={d:.6} sink={d}\n", .{ passes, elapsed, sink });
}
