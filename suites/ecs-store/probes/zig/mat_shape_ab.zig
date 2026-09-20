// Which substrate should a compound store column take? Two candidate
// emissions of the SAME workload — mat4 inverse, one per row — differ only
// in layout and loop structure:
//
//   A  SoA scalars      — 32 columns t00..o33, one f64 each; the shape
//                         today's store emits (690_127's literal output).
//                         16 loads from 16 streams, 16 scattered writes.
//   B  AoS compound     — one [16]f64 cell per row; comptime-unrolled
//                         cofactor math identical to A, but the row's 16
//                         elements are contiguous.
//   C  AoS + naive loop — same cells, but the ranged write emits a runtime
//                         `for i in 0..4, for j in 0..4` with runtime skip
//                         conditions (what a comprehension emits if LLVM
//                         declines to unroll).
//
// One variant per process so they cannot interfere. argv: <variant a|b|c>
// The math is written ONCE (comptime minor table) — the variants differ in
// where the numbers live, never in what is computed.
const std = @import("std");

const N: usize = 10000;
const PASSES: usize = 200;

// det = expansion along row 0; cofactor(i,j) = (-1)^(i+j) * minor(i,j);
// inverse[i][j] = cofactor(j,i) / det. Same operation count everywhere.
fn minor3(t: *const [16]f64, comptime i: usize, comptime j: usize) f64 {
    comptime var m: [9]usize = undefined;
    comptime {
        var n: usize = 0;
        for (0..4) |r| {
            if (r == i) continue;
            for (0..4) |c| {
                if (c == j) continue;
                m[n] = r * 4 + c;
                n += 1;
            }
        }
    }
    return t[m[0]] * (t[m[4]] * t[m[8]] - t[m[5]] * t[m[7]]) -
        t[m[1]] * (t[m[3]] * t[m[8]] - t[m[5]] * t[m[6]]) +
        t[m[2]] * (t[m[3]] * t[m[7]] - t[m[4]] * t[m[6]]);
}

fn det(t: *const [16]f64) f64 {
    return t[0] * minor3(t, 0, 0) - t[1] * minor3(t, 0, 1) +
        t[2] * minor3(t, 0, 2) - t[3] * minor3(t, 0, 3);
}

fn cofactor(t: *const [16]f64, comptime i: usize, comptime j: usize) f64 {
    const sign: f64 = if ((i + j) % 2 == 0) 1.0 else -1.0;
    return sign * minor3(t, i, j);
}

// ---- A: SoA scalar columns (today's shape) -------------------------------

const StoreA = struct {
    t: [16][N]f64 = undefined,
    o: [16][N]f64 = undefined,
    len: usize = N,
};
var sa: StoreA = .{};

fn passA() void {
    for (0..sa.len) |r| {
        // the gather/scatter through a row-local array is what LLVM does
        // with the literal scattered loads anyway (SROA) — it is the honest
        // upper bound for the SoA emission.
        const t: [16]f64 = .{
            sa.t[0][r],  sa.t[1][r],  sa.t[2][r],  sa.t[3][r],
            sa.t[4][r],  sa.t[5][r],  sa.t[6][r],  sa.t[7][r],
            sa.t[8][r],  sa.t[9][r],  sa.t[10][r], sa.t[11][r],
            sa.t[12][r], sa.t[13][r], sa.t[14][r], sa.t[15][r],
        };
        const d = det(&t);
        var o: [16]f64 = undefined;
        inline for (0..4) |i| {
            inline for (0..4) |j| {
                o[i * 4 + j] = cofactor(&t, j, i) / d;
            }
        }
        inline for (0..16) |e| sa.o[e][r] = o[e];
    }
}

// ---- B: AoS compound cells, comptime-unrolled comprehension --------------

const StoreB = struct {
    t: [N][16]f64 = undefined,
    o: [N][16]f64 = undefined,
    len: usize = N,
};
var sb: StoreB = .{};

fn passB() void {
    for (0..sb.len) |r| {
        const t = &sb.t[r];
        const d = det(t);
        inline for (0..4) |i| {
            inline for (0..4) |j| {
                sb.o[r][i * 4 + j] = cofactor(t, j, i) / d;
            }
        }
    }
}

// ---- C: AoS cells, runtime ranged write (naive comprehension) ------------

fn passC() void {
    for (0..sb.len) |r| {
        const t = &sb.t[r];
        const d = det(t);
        // what `e.o[i][j]: cofactor(j,i)/e.det` emits if nothing unrolls:
        // runtime i,j, runtime "exclude row/col" selection.
        for (0..4) |i| {
            for (0..4) |j| {
                // gather the minor's nine elements by skipping row j, col i
                var m: [9]f64 = undefined;
                var n: usize = 0;
                for (0..4) |k| {
                    if (k == j) continue;
                    for (0..4) |l| {
                        if (l == i) continue;
                        m[n] = t[k * 4 + l];
                        n += 1;
                    }
                }
                const sign: f64 = if ((i + j) % 2 == 0) 1.0 else -1.0;
                sb.o[r][i * 4 + j] = sign *
                    (m[0] * (m[4] * m[8] - m[5] * m[7]) -
                        m[1] * (m[3] * m[8] - m[5] * m[6]) +
                        m[2] * (m[3] * m[7] - m[4] * m[6])) / d;
            }
        }
    }
}

var sink: f64 = 0;

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const variant = (args.next() orelse "a")[0];

    // identical seed data both layouts
    var rng = std.Random.DefaultPrng.init(0x5eed);
    const rand = rng.random();
    switch (variant) {
        'a' => for (0..N) |r| {
            inline for (0..16) |e| sa.t[e][r] = rand.float(f64) * 8.0 - 3.0;
        },
        else => for (0..N) |r| {
            inline for (0..16) |e| sb.t[r][e] = rand.float(f64) * 8.0 - 3.0;
        },
    }

    var timer = try std.time.Timer.start();
    switch (variant) {
        'a' => for (0..PASSES) |_| passA(),
        'b' => for (0..PASSES) |_| passB(),
        'c' => for (0..PASSES) |_| passC(),
        else => unreachable,
    }
    const ns = timer.read();

    switch (variant) {
        'a' => for (0..16) |e| {
            sink += sa.o[e][N - 1];
        },
        else => for (0..16) |e| {
            sink += sb.o[N - 1][e];
        },
    }
    std.debug.print("{s} {d} ns ({d} ns/pass) sink={d}\n", .{
        [_]u8{variant}, ns, ns / PASSES, sink,
    });
}
