const std = @import("std");
const Lane = extern struct { fid: u64, w0: u64, w1: u64, w2: u64 };
const Seg = *const fn (sp: [*]Lane, r0: u64, r1: u64, r2: u64) callconv(.auto) u64;

fn fDone(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = sp; _ = r1; _ = r2;
    return r0;
}

// fib(n): n<2 -> n; else fib(n-1) then fib(n-2), sum
fn fFib(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    if (r0 < 2) {
        const f = sp - 1;
        return @call(.always_tail, @as(Seg, @ptrFromInt(f[0].fid)), .{ f, r0, r1, r2 });
    }
    sp[0] = .{ .fid = @intFromPtr(&fFibK1), .w0 = r0, .w1 = 0, .w2 = 0 };
    return @call(.always_tail, fFib, .{ sp + 1, r0 - 1, r1, r2 });
}
fn fFibK1(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = r1;
    const n = sp[0].w0;
    sp[0] = .{ .fid = @intFromPtr(&fFibK2), .w0 = r0, .w1 = 0, .w2 = 0 }; // reuse lane
    return @call(.always_tail, fFib, .{ sp + 1, n - 2, r0, r2 });       // fib(n-2)
}
fn fFibK2(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    const a = sp[0].w0;
    const f = sp - 1;
    return @call(.always_tail, @as(Seg, @ptrFromInt(f[0].fid)), .{ f, a + r0, r1, r2 });
}

// hanoi(n,acc) = hanoi(n-1, hanoi(n-1,acc)+1)
fn fHanoi(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    if (r0 == 0) {
        const f = sp - 1;
        return @call(.always_tail, @as(Seg, @ptrFromInt(f[0].fid)), .{ f, r1, r1, r2 });
    }
    sp[0] = .{ .fid = @intFromPtr(&fHanoiK), .w0 = r0 - 1, .w1 = 0, .w2 = 0 };
    return @call(.always_tail, fHanoi, .{ sp + 1, r0 - 1, r1, r2 });
}
fn fHanoiK(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = r1;
    const p = sp[0].w0;
    return @call(.always_tail, fHanoi, .{ sp, p, r0 + 1, r2 });
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const which = if (args.next()) |a| try std.fmt.parseInt(u64, a, 10) else 0;
    const stk = try std.heap.page_allocator.alloc(Lane, 1 << 24);
    stk[0] = .{ .fid = @intFromPtr(&fDone), .w0 = 0, .w1 = 0, .w2 = 0 };
    const r: u64 = if (which == 0) fFib(stk.ptr + 1, 35, 0, 0) else fHanoi(stk.ptr + 1, 25, 0, 0);
    std.debug.print("{d}\n", .{r});
}
