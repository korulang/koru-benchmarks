const std = @import("std");

const Lane = extern struct { fid: u64, w0: u64, w1: u64, w2: u64 };
const Seg = *const fn (sp: [*]Lane, r0: u64, r1: u64, r2: u64) callconv(.auto) u64;

fn fDone(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = sp; _ = r1; _ = r2;
    return r0;
}

fn fAck(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    if (r0 == 0) {
        const f = sp - 1;
        return @call(.always_tail, @as(Seg, @ptrFromInt(f[0].fid)), .{ f, r1 + 1, r1, r2 });
    }
    if (r1 == 0) {
        return @call(.always_tail, fAck, .{ sp, r0 - 1, 1, r2 });
    }
    sp[0] = .{ .fid = @intFromPtr(&fAckK), .w0 = r0, .w1 = 0, .w2 = 0 };
    return @call(.always_tail, fAck, .{ sp + 1, r0, r1 - 1, r2 });
}

fn fAckK(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = r1;
    const m = sp[0].w0;
    return @call(.always_tail, fAck, .{ sp, m - 1, r0, r2 });
}

pub fn main() !void {
    const stk = try std.heap.page_allocator.alloc(Lane, 1 << 22);
    stk[0] = .{ .fid = @intFromPtr(&fDone), .w0 = 0, .w1 = 0, .w2 = 0 };
    std.debug.print("{d}\n", .{fAck(stk.ptr + 1, 3, 10, 0)});
}
