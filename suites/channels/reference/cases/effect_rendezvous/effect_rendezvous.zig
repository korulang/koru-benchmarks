// effect_rendezvous — the floor. What the Koru kernel emits is a
// statically-dispatched handler call per element, so the same-substrate
// control is exactly that: a handler struct whose `send` accumulates,
// called in a counted loop. If the Koru row lands anywhere else, the
// effect machinery is costing something over a call.
const std = @import("std");

const Handlers = struct {
    sum: usize = 0,
    fn send(self: *Handlers, v: usize) void {
        self.sum += v;
    }
};

pub fn main() !void {
    var h = Handlers{};
    for (0..1_000_000) |i| h.send(i);
    var buf: [32]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{d}\n", .{h.sum});
    _ = try std.posix.write(1, s);
}
