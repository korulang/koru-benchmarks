const std = @import("std");
const Io = std.Io;

const benchmark = @import("benchmark.zig");
const Helper = @import("helper.zig").Helper;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const io = init.io;

    const now = std.Io.Clock.now(.boot, io);
    const timestamp_ns = now.toNanoseconds();
    const timestamp_ms = @divTrunc(timestamp_ns, 1_000);
    std.debug.print("start: {d}\n", .{timestamp_ms});

    var helper = try Helper.init(gpa);
    defer helper.deinit();

    const args = try init.minimal.args.toSlice(arena);

    const config_path = if (args.len > 1) args[1] else "../run.js";
    const single_bench = if (args.len > 2) args[2] else null;

    try helper.loadConfig(io, config_path);

    try benchmark.runAllBenchmarks(gpa, &helper, io, single_bench);

    const cwd = Io.Dir.cwd();
    const marker_file = try cwd.createFile(io, "/tmp/recompile_marker", .{});
    defer marker_file.close(io);

    try marker_file.writeStreamingAll(io, "RECOMPILE_MARKER_0");
}
