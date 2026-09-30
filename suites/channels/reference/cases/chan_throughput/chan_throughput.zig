// chan_throughput — the same-substrate control. The SAME Vyukov MpmcRing
// that std/channel emits (verbatim from koru_std/rings.kz), driven by the
// SAME schedule the Koru kernel runs: each pass a producer feeds up to
// 128 sends, stopping at full; then four consumers take one dequeue each.
// No pump, no transform plumbing, no channel vocabulary — just the ring.
// This row isolates what the transform costs over the raw data plane.
const std = @import("std");

const CacheLine = 64;

pub fn MpmcRing(comptime T: type, comptime capacity: usize) type {
    if (capacity & (capacity - 1) != 0) {
        @compileError("Ring capacity must be power of 2");
    }

    const Slot = struct {
        seq: std.atomic.Value(usize),
        value: T,
    };

    return struct {
        const Self = @This();

        head: std.atomic.Value(usize) align(CacheLine),
        _pad1: [CacheLine - @sizeOf(std.atomic.Value(usize))]u8 = undefined,

        tail: std.atomic.Value(usize) align(CacheLine),
        _pad2: [CacheLine - @sizeOf(std.atomic.Value(usize))]u8 = undefined,

        slots: [capacity]Slot align(CacheLine),

        pub fn init() Self {
            @setEvalBranchQuota(capacity * 8);
            var self = Self{
                .head = std.atomic.Value(usize).init(0),
                .tail = std.atomic.Value(usize).init(0),
                .slots = undefined,
            };

            for (&self.slots, 0..) |*slot, i| {
                slot.seq = std.atomic.Value(usize).init(i);
                slot.value = undefined;
            }

            return self;
        }

        pub fn tryEnqueue(self: *Self, value: T) bool {
            var pos = self.head.load(.monotonic);

            while (true) {
                const slot = &self.slots[pos & (capacity - 1)];
                const seq = slot.seq.load(.acquire);
                const dif = @as(isize, @intCast(seq)) -% @as(isize, @intCast(pos));

                if (dif == 0) {
                    if (self.head.cmpxchgWeak(
                        pos,
                        pos + 1,
                        .monotonic,
                        .monotonic,
                    ) == null) {
                        slot.value = value;
                        slot.seq.store(pos + 1, .release);
                        return true;
                    }
                    pos = self.head.load(.monotonic);
                } else if (dif < 0) {
                    return false;
                } else {
                    pos = self.head.load(.monotonic);
                    std.Thread.yield() catch {};
                }
            }
        }

        pub fn tryDequeue(self: *Self) ?T {
            var pos = self.tail.load(.monotonic);

            while (true) {
                const slot = &self.slots[pos & (capacity - 1)];
                const seq = slot.seq.load(.acquire);
                const dif = @as(isize, @intCast(seq)) -% @as(isize, @intCast(pos + 1));

                if (dif == 0) {
                    if (self.tail.cmpxchgWeak(
                        pos,
                        pos + 1,
                        .monotonic,
                        .monotonic,
                    ) == null) {
                        const value = slot.value;
                        slot.seq.store(pos + capacity, .release);
                        return value;
                    }
                    pos = self.tail.load(.monotonic);
                } else if (dif < 0) {
                    return null;
                } else {
                    pos = self.tail.load(.monotonic);
                    std.Thread.yield() catch {};
                }
            }
        }
    };
}

const Msg = struct { v: i64 };

pub fn main() void {
    const total: i64 = 1_000_000;
    const batch: i64 = 128;
    const consumers = 4;
    var ring = MpmcRing(Msg, 1024).init();

    var sent: i64 = 0;
    var got: i64 = 0;
    var sum: i64 = 0;
    while (got < total) {
        // producer step: bounded batch, ends early on full
        var fed: i64 = 0;
        while (fed < batch and sent < total) {
            if (!ring.tryEnqueue(.{ .v = sent })) break;
            sent += 1;
            fed += 1;
        }
        // consumer steps: four competing units, one dequeue each
        for (0..consumers) |_| {
            if (ring.tryDequeue()) |v| {
                sum += v.v;
                got += 1;
            }
        }
    }
    var buf: [32]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "{d}\n", .{sum}) catch unreachable;
    std.fs.File.stdout().writeAll(line) catch unreachable;
}
