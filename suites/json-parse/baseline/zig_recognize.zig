// Baseline: hand-rolled Zig JSON RECOGNIZER — the true same-lane rival to
// the koru std/parser entry. Validation only: no allocation, no token
// materialization, answer = "is this JSON?" plus the consumed span. Written
// to be a fair, honestly-tuned rival: byte-switch recursive descent, the
// full RFC 8259 surface (whitespace anywhere, \uXXXX escapes, control-char
// rejection, full number grammar). Note the lane nuance recorded in
// README.md: this recognizer is GENERAL, while the koru grammar is
// comptime-specialized to the doc's dialect — specialization for free being
// the library's whole pitch. Same protocol: argv doc, 3s timed passes.
const std = @import("std");

const P = struct {
    s: []const u8,
    i: usize = 0,

    inline fn skipWs(p: *P) void {
        while (p.i < p.s.len) : (p.i += 1) {
            switch (p.s[p.i]) {
                ' ', '\t', '\n', '\r' => {},
                else => return,
            }
        }
    }

    inline fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn value(p: *P) bool {
        p.skipWs();
        if (p.i >= p.s.len) return false;
        switch (p.s[p.i]) {
            '"' => return p.string(),
            '{' => return p.object(),
            '[' => return p.array(),
            't' => return p.lit("true"),
            'f' => return p.lit("false"),
            'n' => return p.lit("null"),
            '-', '0'...'9' => return p.number(),
            else => return false,
        }
    }

    fn lit(p: *P, l: []const u8) bool {
        if (p.i + l.len > p.s.len) return false;
        if (!std.mem.eql(u8, p.s[p.i .. p.i + l.len], l)) return false;
        p.i += l.len;
        return true;
    }

    fn string(p: *P) bool {
        p.i += 1; // opening quote
        while (p.i < p.s.len) {
            const c = p.s[p.i];
            if (c == '"') {
                p.i += 1;
                return true;
            }
            if (c == '\\') {
                p.i += 1;
                if (p.i >= p.s.len) return false;
                switch (p.s[p.i]) {
                    '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => p.i += 1,
                    'u' => {
                        if (p.i + 4 >= p.s.len) return false;
                        var k: usize = 1;
                        while (k <= 4) : (k += 1) {
                            switch (p.s[p.i + k]) {
                                '0'...'9', 'a'...'f', 'A'...'F' => {},
                                else => return false,
                            }
                        }
                        p.i += 5;
                    },
                    else => return false,
                }
            } else if (c < 0x20) {
                return false; // raw control character
            } else {
                p.i += 1;
            }
        }
        return false; // unterminated
    }

    fn number(p: *P) bool {
        if (p.s[p.i] == '-') p.i += 1;
        if (p.i >= p.s.len) return false;
        if (p.s[p.i] == '0') {
            p.i += 1;
        } else if (p.s[p.i] >= '1' and p.s[p.i] <= '9') {
            while (p.i < p.s.len and isDigit(p.s[p.i])) p.i += 1;
        } else {
            return false;
        }
        if (p.i < p.s.len and p.s[p.i] == '.') {
            p.i += 1;
            if (p.i >= p.s.len or !isDigit(p.s[p.i])) return false;
            while (p.i < p.s.len and isDigit(p.s[p.i])) p.i += 1;
        }
        if (p.i < p.s.len and (p.s[p.i] == 'e' or p.s[p.i] == 'E')) {
            p.i += 1;
            if (p.i < p.s.len and (p.s[p.i] == '+' or p.s[p.i] == '-')) p.i += 1;
            if (p.i >= p.s.len or !isDigit(p.s[p.i])) return false;
            while (p.i < p.s.len and isDigit(p.s[p.i])) p.i += 1;
        }
        return true;
    }

    fn object(p: *P) bool {
        p.i += 1; // {
        p.skipWs();
        if (p.i < p.s.len and p.s[p.i] == '}') {
            p.i += 1;
            return true;
        }
        while (true) {
            p.skipWs();
            if (p.i >= p.s.len or p.s[p.i] != '"') return false;
            if (!p.string()) return false;
            p.skipWs();
            if (p.i >= p.s.len or p.s[p.i] != ':') return false;
            p.i += 1;
            if (!p.value()) return false;
            p.skipWs();
            if (p.i >= p.s.len) return false;
            switch (p.s[p.i]) {
                ',' => p.i += 1,
                '}' => {
                    p.i += 1;
                    return true;
                },
                else => return false,
            }
        }
    }

    fn array(p: *P) bool {
        p.i += 1; // [
        p.skipWs();
        if (p.i < p.s.len and p.s[p.i] == ']') {
            p.i += 1;
            return true;
        }
        while (true) {
            if (!p.value()) return false;
            p.skipWs();
            if (p.i >= p.s.len) return false;
            switch (p.s[p.i]) {
                ',' => p.i += 1,
                ']' => {
                    p.i += 1;
                    return true;
                },
                else => return false,
            }
        }
    }
};

fn recognize(doc: []const u8) ?usize {
    var p = P{ .s = doc };
    if (!p.value()) return null;
    p.skipWs();
    if (p.i != doc.len) return null; // whole-input consumption, like the koru entry
    return p.i;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    if (args.len < 2) {
        std.debug.print("usage: zig_recognize <doc.json>\n", .{});
        return error.Usage;
    }
    const doc = try std.fs.cwd().readFileAlloc(alloc, args[1], 64 * 1024 * 1024);

    if (recognize(doc) == null) {
        std.debug.print("INVALID\n", .{});
        std.process.exit(1);
    }

    const start = std.time.nanoTimestamp();
    const deadline = start + 3 * 1_000_000_000;
    var passes: i64 = 0;
    var sink: usize = 0;
    while (std.time.nanoTimestamp() < deadline) {
        sink +%= recognize(doc) orelse unreachable;
        passes += 1;
    }
    const elapsed: f64 = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1e9;
    std.debug.print("passes={d} seconds={d:.6} sink={d}\n", .{ passes, elapsed, sink });
}
