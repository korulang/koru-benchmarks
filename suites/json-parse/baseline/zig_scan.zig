// Baseline: Zig std.json.Scanner token walk — VALIDATION category (no tree
// built), the closest lane to the Koru recognizer. Same protocol as the Koru
// entry: read the doc from argv[1], run timed passes for 3 wall seconds,
// print passes and elapsed.
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    if (args.len < 2) {
        std.debug.print("usage: zig_scan <doc.json>\n", .{});
        return error.Usage;
    }
    const doc = try std.fs.cwd().readFileAlloc(alloc, args[1], 64 * 1024 * 1024);

    const start = std.time.nanoTimestamp();
    const deadline = start + 3 * 1_000_000_000;
    var passes: i64 = 0;
    var sink: usize = 0;
    while (std.time.nanoTimestamp() < deadline) {
        var scanner = std.json.Scanner.initCompleteInput(alloc, doc);
        defer scanner.deinit();
        while (true) {
            const tok = try scanner.next();
            if (tok == .end_of_document) break;
            sink +%= 1;
        }
        passes += 1;
    }
    const elapsed: f64 = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1e9;
    std.debug.print("passes={d} seconds={d:.6} tokens_sink={d}\n", .{ passes, elapsed, sink });
}
