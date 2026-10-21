const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CacheSimulation = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    result_val: u32,
    values_size: i64,
    cache_size: i64,
    cache: LRUCache,
    hits: u32,
    misses: u32,

    const Node = struct {
        key: []const u8,
        value: []const u8,
        prev: ?*Node,
        next: ?*Node,
    };

    const LRUCache = struct {
        capacity: usize,
        map: std.StringHashMap(*Node),
        head: ?*Node,
        tail: ?*Node,
        size: usize,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, capacity: usize) LRUCache {
            return LRUCache{
                .capacity = capacity,
                .map = std.StringHashMap(*Node).init(allocator),
                .head = null,
                .tail = null,
                .size = 0,
                .allocator = allocator,
            };
        }

        fn deinit(self: *LRUCache) void {
            var current = self.head;
            while (current) |node| {
                const next = node.next;
                self.allocator.free(node.key);
                self.allocator.free(node.value);
                self.allocator.destroy(node);
                current = next;
            }
            self.map.deinit();
        }

        fn moveToFront(self: *LRUCache, node: *Node) void {
            if (node == self.head) return;

            if (node.prev) |prev| prev.next = node.next;
            if (node.next) |next| next.prev = node.prev;
            if (node == self.tail) self.tail = node.prev;

            node.prev = null;
            node.next = self.head;
            if (self.head) |head| head.prev = node;
            self.head = node;

            if (self.tail == null) self.tail = node;
        }

        fn addToFront(self: *LRUCache, node: *Node) void {
            node.next = self.head;
            if (self.head) |head| head.prev = node;
            self.head = node;
            if (self.tail == null) self.tail = node;
        }

        fn removeOldest(self: *LRUCache) void {
            const oldest = self.tail orelse return;

            _ = self.map.remove(oldest.key);

            if (oldest.prev) |prev| {
                prev.next = null;
                self.tail = prev;
            } else {
                self.head = null;
                self.tail = null;
            }

            self.allocator.free(oldest.key);
            self.allocator.free(oldest.value);
            self.allocator.destroy(oldest);
            self.size -= 1;
        }

        fn get(self: *LRUCache, key: []const u8) ?[]const u8 {
            const node = self.map.get(key) orelse return null;
            self.moveToFront(node);
            return node.value;
        }

        fn put(self: *LRUCache, key: []const u8, value: []const u8) !void {
            if (self.map.get(key)) |node| {
                self.allocator.free(node.value);
                node.value = try self.allocator.dupe(u8, value);
                self.moveToFront(node);
                return;
            }

            if (self.size >= self.capacity) {
                self.removeOldest();
            }

            const node = try self.allocator.create(Node);

            node.key = try self.allocator.dupe(u8, key);
            node.value = try self.allocator.dupe(u8, value);
            node.prev = null;
            node.next = null;

            try self.map.put(node.key, node);
            self.addToFront(node);
            self.size += 1;
        }

        fn getSize(self: *LRUCache) usize {
            return self.size;
        }
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CacheSimulation {
        const self = try allocator.create(CacheSimulation);
        errdefer allocator.destroy(self);

        const values_size = helper.config_i64("Etc::CacheSimulation", "values");
        const cache_size = helper.config_i64("Etc::CacheSimulation", "size");

        self.* = CacheSimulation{
            .allocator = allocator,
            .helper = helper,
            .result_val = 5432,
            .values_size = values_size,
            .cache_size = cache_size,
            .cache = LRUCache.init(allocator, @intCast(cache_size)),
            .hits = 0,
            .misses = 0,
        };

        return self;
    }

    pub fn deinit(self: *CacheSimulation) void {
        self.cache.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CacheSimulation) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Etc::CacheSimulation");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.hits = 0;
        self.misses = 0;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        var n: usize = 0;
        while (n < 1000) {
            const key_num = self.helper.nextInt(@intCast(self.values_size));

            var key_buf: [32]u8 = undefined;
            const key = std.fmt.bufPrint(&key_buf, "item_{d}", .{key_num}) catch unreachable;

            if (self.cache.get(key)) |_| {
                self.hits += 1;
                var val_buf: [32]u8 = undefined;
                const value = std.fmt.bufPrint(&val_buf, "updated_{d}", .{iteration_id}) catch unreachable;
                self.cache.put(key, value) catch return;
            } else {
                self.misses += 1;
                var val_buf: [32]u8 = undefined;
                const value = std.fmt.bufPrint(&val_buf, "new_{d}", .{iteration_id}) catch unreachable;
                self.cache.put(key, value) catch return;
            }
            n += 1;
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        var final_result: u32 = self.result_val;
        final_result = (final_result << 5) + self.hits;
        final_result = (final_result << 5) + self.misses;
        final_result = (final_result << 5) + @as(u32, @intCast(self.cache.getSize()));
        return final_result;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
