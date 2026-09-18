const std = @import("std");
const Lane = extern struct { fid: u64, w0: u64, w1: u64, w2: u64, w3: u64 };
const Seg = *const fn (sp: [*]Lane, r0: u64, r1: u64, r2: u64) callconv(.auto) u64;

fn fDone(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = sp; _ = r1; _ = r2;
    return r0;
}

// tak(x,y,z): x<=y -> z; else tak(tak(x-1,y,z), tak(y-1,z,x), tak(z-1,x,y))
// args ride r0=x, r1=y, r2=z.
fn fTak(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    if (r0 <= r1) {
        const f = sp - 1;
        return @call(.always_tail, @as(Seg, @ptrFromInt(f[0].fid)), .{ f, r2, r1, r2 });
    }
    sp[0] = .{ .fid = @intFromPtr(&fTakK1), .w0 = r0, .w1 = r1, .w2 = r2, .w3 = 0 };
    return @call(.always_tail, fTak, .{ sp + 1, r0 - 1, r1, r2 }); // tak(x-1,y,z)
}
fn fTakK1(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = r1; _ = r2;
    const x = sp[0].w0;
    const y = sp[0].w1;
    const z = sp[0].w2;
    sp[0] = .{ .fid = @intFromPtr(&fTakK2), .w0 = r0, .w1 = x, .w2 = y, .w3 = z };
    return @call(.always_tail, fTak, .{ sp + 1, y - 1, z, x }); // tak(y-1,z,x)
}
fn fTakK2(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = r1; _ = r2;
    const a = sp[0].w0;
    const x = sp[0].w1;
    const y = sp[0].w2;
    const z = sp[0].w3;
    sp[0] = .{ .fid = @intFromPtr(&fTakK3), .w0 = a, .w1 = r0, .w2 = 0, .w3 = 0 };
    return @call(.always_tail, fTak, .{ sp + 1, z - 1, x, y }); // tak(z-1,x,y)
}
fn fTakK3(sp: [*]Lane, r0: u64, r1: u64, r2: u64) u64 {
    _ = r1; _ = r2;
    const a = sp[0].w0;
    const b = sp[0].w1;
    return @call(.always_tail, fTak, .{ sp, a, b, r0 }); // tak(a,b,c) — consumes lane
}

pub fn main() !void {
    const stk = try std.heap.page_allocator.alloc(Lane, 1 << 24);
    stk[0] = .{ .fid = @intFromPtr(&fDone), .w0 = 0, .w1 = 0, .w2 = 0, .w3 = 0 };
    std.debug.print("{d}\n", .{fTak(stk.ptr + 1, 24, 16, 8)});
}
