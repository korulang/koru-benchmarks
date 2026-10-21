const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const json = std.json;

pub const Helper = struct {
    const IM: i32 = 139968;
    const IA: i32 = 3877;
    const IC: i32 = 29573;
    const INIT: i32 = 42;

    const ConfigValue = struct {
        arg: []const u8,
        expected: i64,
    };

    last: i32,
    config: json.ObjectMap,
    config_parsed: ?json.Parsed(json.Value) = null,
    order: [][]const u8,
    order_arena: std.heap.ArenaAllocator,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !Helper {
        return Helper{
            .last = INIT,
            .config = try json.ObjectMap.init(allocator, &[_][]const u8{}, &[_]json.Value{}),
            .config_parsed = null,
            .order = &[_][]const u8{},
            .order_arena = std.heap.ArenaAllocator.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Helper) void {
        if (self.config_parsed) |*parsed| {
            parsed.deinit();
        }
        for (self.order) |name| {
            self.allocator.free(name);
        }
        self.config.deinit(self.allocator);
        self.allocator.free(self.order);
        self.order_arena.deinit();
    }

    pub fn reset(self: *Helper) void {
        self.last = INIT;
    }

    fn positiveMod(a: i32, b: i32) i32 {
        const rem = @rem(a, b);
        return if (rem < 0) rem + b else rem;
    }

    pub fn nextInt(self: *Helper, max: i32) i32 {
        self.last = positiveMod(self.last *% IA +% IC, IM);
        return @intFromFloat(@as(f64, @floatFromInt(self.last)) * @as(f64, @floatFromInt(max)) / @as(f64, @floatFromInt(IM)));
    }

    pub fn nextIntRange(self: *Helper, from: i32, to: i32) i32 {
        return self.nextInt(to - from + 1) + from;
    }

    pub fn nextFloat(self: *Helper, max: f64) f64 {
        self.last = positiveMod(self.last *% IA +% IC, IM);
        return max * @as(f64, @floatFromInt(self.last)) / @as(f64, @floatFromInt(IM));
    }

    pub fn checksumString(_: *Helper, v: []const u8) u32 {
        var hash: u32 = 5381;
        for (v) |byte| {
            hash = ((hash << 5) +% hash) +% byte;
        }
        return hash;
    }

    pub fn checksumBytes(_: *Helper, v: []const u8) u32 {
        var hash: u32 = 5381;
        for (v) |byte| {
            hash = ((hash << 5) +% hash) +% byte;
        }
        return hash;
    }

    pub fn checksumFloat(self: *Helper, v: f64) u32 {
        var buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.7}", .{v}) catch "0.0000000";
        return self.checksumString(formatted);
    }

    pub fn loadConfig(self: *Helper, io: Io, filename: ?[]const u8) !void {
        const actual_filename = filename orelse "../run.js";

        const content = try Io.Dir.cwd().readFileAlloc(io, actual_filename, self.allocator, .unlimited);
        defer self.allocator.free(content);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, content, .{});
        self.config_parsed = parsed;

        const array = parsed.value;
        if (array != .array) return error.InvalidConfig;

        var old_config = self.config;
        self.config = try json.ObjectMap.init(self.allocator, &[_][]const u8{}, &[_]json.Value{});
        old_config.deinit(self.allocator);

        var order_list = std.ArrayList([]const u8).empty;
        defer order_list.deinit(self.allocator);

        for (array.array.items) |item| {
            if (item == .object) {
                if (item.object.get("name")) |name_field| {
                    if (name_field == .string) {
                        const name = name_field.string;
                        const name_copy = try self.allocator.dupe(u8, name);

                        try order_list.append(self.allocator, name_copy);
                        try self.config.put(self.allocator, name_copy, item);
                    }
                }
            }
        }

        self.order = try order_list.toOwnedSlice(self.allocator);
    }

    pub fn config_i64(self: *Helper, class_name: []const u8, field_name: []const u8) i64 {
        if (self.config.get(class_name)) |class_config| {
            if (class_config == .object) {
                if (class_config.object.get(field_name)) |field_value| {
                    if (field_value == .integer) return field_value.integer;
                    if (field_value == .float) return @as(i64, @intFromFloat(field_value.float));
                    if (field_value == .string) {
                        return std.fmt.parseInt(i64, field_value.string, 10) catch 0;
                    }
                }
            }
        }
        std.debug.print("Config not found for {s}, field: {s}\n", .{ class_name, field_name });
        return 0;
    }

    pub fn config_s(self: *Helper, class_name: []const u8, field_name: []const u8) []const u8 {
        if (self.config.get(class_name)) |class_config| {
            if (class_config == .object) {
                if (class_config.object.get(field_name)) |field_value| {
                    if (field_value == .string) return field_value.string;
                }
            }
        }
        std.debug.print("Config not found for {s}, field: {s}\n", .{ class_name, field_name });
        return "";
    }

    pub fn next_int(self: *Helper, max: i32) i32 {
        return self.nextInt(max);
    }

    pub fn next_int_range(self: *Helper, from: i32, to: i32) i32 {
        return self.nextIntRange(from, to);
    }

    pub fn next_float(self: *Helper, max: f64) f64 {
        return self.nextFloat(max);
    }

    pub fn checksum(self: *Helper, v: []const u8) u32 {
        return self.checksumString(v);
    }

    pub fn checksum_f64(self: *Helper, v: f64) u32 {
        return self.checksumFloat(v);
    }
};
