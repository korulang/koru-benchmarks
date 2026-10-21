const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const MazeGenerator = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    result_val: u32,
    maze: ?*Maze,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .prepare = prepareImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub const CellKind = enum(u8) {
        wall = 0,
        space = 1,
        start = 2,
        finish = 3,
        border = 4,
        path = 5,

        pub fn isWalkable(self: CellKind) bool {
            return self == .space or self == .start or self == .finish;
        }
    };

    pub const Cell = struct {
        kind: CellKind,
        neighbors: [4]*Cell,
        neighbor_count: u8,
        x: i32,
        y: i32,

        pub fn reset(self: *Cell) void {
            if (self.kind == .space) {
                self.kind = .wall;
            }
        }

        pub fn addNeighbor(self: *Cell, cell: *Cell) void {
            if (self.neighbor_count < 4) {
                self.neighbors[self.neighbor_count] = cell;
                self.neighbor_count += 1;
            }
        }
    };

    pub const Maze = struct {
        width: i32,
        height: i32,
        cells: [][]Cell,
        start: *Cell,
        finish: *Cell,
        allocator: std.mem.Allocator,
        helper: *Helper,

        pub fn init(allocator: std.mem.Allocator, helper: *Helper, width: i32, height: i32) !*Maze {
            const w = @max(width, 5);
            const h = @max(height, 5);

            const rows = try allocator.alloc([]Cell, @intCast(h));
            errdefer allocator.free(rows);

            var allocated: usize = 0;
            errdefer {
                var k: usize = 0;
                while (k < allocated) : (k += 1) allocator.free(rows[k]);
            }

            var y: usize = 0;
            while (y < @as(usize, @intCast(h))) : (y += 1) {
                rows[y] = try allocator.alloc(Cell, @intCast(w));
                allocated += 1;

                var x: usize = 0;
                while (x < @as(usize, @intCast(w))) : (x += 1) {
                    rows[y][x] = Cell{
                        .kind = .wall,
                        .neighbors = undefined,
                        .neighbor_count = 0,
                        .x = @intCast(x),
                        .y = @intCast(y),
                    };
                }
            }

            const self = try allocator.create(Maze);
            self.* = Maze{
                .width = w,
                .height = h,
                .cells = rows,
                .start = &rows[1][1],
                .finish = &rows[@intCast(h - 2)][@intCast(w - 2)],
                .allocator = allocator,
                .helper = helper,
            };
            self.start.kind = .start;
            self.finish.kind = .finish;

            try self.updateNeighbors();
            return self;
        }

        pub fn deinit(self: *Maze) void {
            for (self.cells) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(self.cells);
            self.allocator.destroy(self);
        }

        pub fn updateNeighbors(self: *Maze) !void {
            var y: i32 = 0;
            while (y < self.height) : (y += 1) {
                var x: i32 = 0;
                while (x < self.width) : (x += 1) {
                    const cell = &self.cells[@intCast(y)][@intCast(x)];
                    cell.neighbor_count = 0;

                    if (x > 0 and y > 0 and x < self.width - 1 and y < self.height - 1) {
                        cell.addNeighbor(&self.cells[@intCast(y - 1)][@intCast(x)]);
                        cell.addNeighbor(&self.cells[@intCast(y + 1)][@intCast(x)]);
                        cell.addNeighbor(&self.cells[@intCast(y)][@intCast(x + 1)]);
                        cell.addNeighbor(&self.cells[@intCast(y)][@intCast(x - 1)]);

                        var t: usize = 0;
                        while (t < 4) : (t += 1) {
                            const i: usize = @intCast(self.helper.nextInt(4));
                            const j: usize = @intCast(self.helper.nextInt(4));
                            if (i != j) {
                                const temp = cell.neighbors[i];
                                cell.neighbors[i] = cell.neighbors[j];
                                cell.neighbors[j] = temp;
                            }
                        }
                    } else {
                        cell.kind = .border;
                    }
                }
            }
        }

        pub fn reset(self: *Maze) void {
            for (self.cells) |row| {
                for (row) |*cell| {
                    cell.reset();
                }
            }
            self.start.kind = .start;
            self.finish.kind = .finish;
        }

        pub fn dig(self: *Maze, start_cell: *Cell) !void {
            const max_size: usize = @intCast(self.width * self.height);
            var stack = try std.ArrayListUnmanaged(*Cell).initCapacity(self.allocator, max_size);
            defer stack.deinit(self.allocator);

            stack.appendAssumeCapacity(start_cell);

            while (stack.items.len > 0) {
                const cell = stack.pop().?;

                var walkable: u32 = 0;
                var i: u8 = 0;
                while (i < cell.neighbor_count) : (i += 1) {
                    if (cell.neighbors[i].kind.isWalkable()) walkable += 1;
                }

                if (walkable != 1) continue;

                cell.kind = .space;

                i = 0;
                while (i < cell.neighbor_count) : (i += 1) {
                    const n = cell.neighbors[i];
                    if (n.kind == .wall) {
                        try stack.append(self.allocator, n);
                    }
                }
            }
        }

        pub fn ensureOpenFinish(self: *Maze, cell: *Cell) void {
            cell.kind = .space;

            var walkable: u32 = 0;
            var i: u8 = 0;
            while (i < cell.neighbor_count) : (i += 1) {
                if (cell.neighbors[i].kind.isWalkable()) walkable += 1;
            }

            if (walkable > 1) return;

            i = 0;
            while (i < cell.neighbor_count) : (i += 1) {
                const n = cell.neighbors[i];
                if (n.kind == .wall) {
                    self.ensureOpenFinish(n);
                }
            }
        }

        pub fn generate(self: *Maze) !void {
            var i: u8 = 0;
            while (i < self.start.neighbor_count) : (i += 1) {
                const n = self.start.neighbors[i];
                if (n.kind == .wall) {
                    try self.dig(n);
                }
            }

            i = 0;
            while (i < self.finish.neighbor_count) : (i += 1) {
                const n = self.finish.neighbors[i];
                if (n.kind == .wall) {
                    self.ensureOpenFinish(n);
                }
            }
        }

        pub fn middleCell(self: *const Maze) *Cell {
            return &self.cells[@intCast(@divTrunc(self.height, 2))][@intCast(@divTrunc(self.width, 2))];
        }

        pub fn checksum(self: *const Maze) u32 {
            var hasher: u32 = 2166136261;
            const prime: u32 = 16777619;

            for (self.cells) |row| {
                for (row) |cell| {
                    if (cell.kind == .space) {
                        const val: u32 = @intCast(cell.x * cell.y);
                        hasher = (hasher ^ val) *% prime;
                    }
                }
            }
            return hasher;
        }
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeGenerator {
        const w = helper.config_i64("Maze::Generator", "w");
        const h = helper.config_i64("Maze::Generator", "h");
        const self = try allocator.create(MazeGenerator);
        self.* = MazeGenerator{
            .allocator = allocator,
            .helper = helper,
            .width = @intCast(w),
            .height = @intCast(h),
            .result_val = 0,
            .maze = try Maze.init(allocator, helper, @intCast(w), @intCast(h)),
        };
        return self;
    }

    pub fn deinit(self: *MazeGenerator) void {
        if (self.maze) |m| {
            m.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeGenerator) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Maze::Generator");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            m.reset();
            m.generate() catch return;
            self.result_val +%= @backingInt(m.middleCell().kind);
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            return self.result_val +% m.checksum();
        }
        return 0;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const MazeBFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    result_val: u32,
    maze: ?*MazeGenerator.Maze,
    path: std.ArrayListUnmanaged(*MazeGenerator.Cell),

    const PathNode = struct {
        cell: *MazeGenerator.Cell,
        parent: i32,
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeBFS {
        const w = helper.config_i64("Maze::BFS", "w");
        const h = helper.config_i64("Maze::BFS", "h");
        const self = try allocator.create(MazeBFS);
        self.* = MazeBFS{
            .allocator = allocator,
            .helper = helper,
            .width = @intCast(w),
            .height = @intCast(h),
            .result_val = 0,
            .maze = try MazeGenerator.Maze.init(allocator, helper, @intCast(w), @intCast(h)),
            .path = .empty,
        };
        return self;
    }

    pub fn deinit(self: *MazeBFS) void {
        if (self.maze) |m| {
            m.deinit();
        }
        self.path.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeBFS) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Maze::BFS");
    }

    fn bfs(self: *MazeBFS, start: *MazeGenerator.Cell, target: *MazeGenerator.Cell) !std.ArrayListUnmanaged(*MazeGenerator.Cell) {
        if (start == target) {
            var result = std.ArrayListUnmanaged(*MazeGenerator.Cell).empty;
            try result.append(self.allocator, start);
            return result;
        }

        const size: usize = @intCast(self.width * self.height);

        var queue = std.ArrayListUnmanaged(i32).empty;
        defer queue.deinit(self.allocator);

        const visited = try self.allocator.alloc(bool, size);
        defer self.allocator.free(visited);
        @memset(visited, false);

        var path_nodes = std.ArrayListUnmanaged(PathNode).empty;
        defer path_nodes.deinit(self.allocator);

        visited[@intCast(start.y * self.width + start.x)] = true;
        try path_nodes.append(self.allocator, PathNode{ .cell = start, .parent = -1 });
        try queue.append(self.allocator, 0);

        var head: usize = 0;
        while (head < queue.items.len) {
            const path_id = queue.items[head];
            head += 1;
            const node = path_nodes.items[@intCast(path_id)];

            var i: u8 = 0;
            while (i < node.cell.neighbor_count) : (i += 1) {
                const neighbor = node.cell.neighbors[i];

                if (neighbor == target) {
                    var result = std.ArrayListUnmanaged(*MazeGenerator.Cell).empty;
                    errdefer result.deinit(self.allocator);
                    try result.append(self.allocator, target);
                    var cur = path_id;
                    while (cur >= 0) {
                        try result.append(self.allocator, path_nodes.items[@intCast(cur)].cell);
                        cur = path_nodes.items[@intCast(cur)].parent;
                    }
                    std.mem.reverse(*MazeGenerator.Cell, result.items);
                    return result;
                }

                if (neighbor.kind.isWalkable()) {
                    const n_idx: usize = @intCast(neighbor.y * self.width + neighbor.x);
                    if (!visited[n_idx]) {
                        visited[n_idx] = true;
                        try path_nodes.append(self.allocator, PathNode{ .cell = neighbor, .parent = path_id });
                        try queue.append(self.allocator, @intCast(path_nodes.items.len - 1));
                    }
                }
            }
        }

        return std.ArrayListUnmanaged(*MazeGenerator.Cell).empty;
    }

    fn midCellChecksum(path: std.ArrayListUnmanaged(*MazeGenerator.Cell)) u32 {
        if (path.items.len == 0) return 0;
        const cell = path.items[path.items.len / 2];
        return @intCast(cell.x * cell.y);
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            self.path.deinit(self.allocator);
            self.path = self.bfs(m.start, m.finish) catch return;
            self.result_val +%= @intCast(self.path.items.len);
        }
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        self.maze.?.generate() catch return;
        self.result_val = 0;
        self.path = .empty;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        return self.result_val +% midCellChecksum(self.path);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const MazeAStar = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    result_val: u32,
    maze: ?*MazeGenerator.Maze,
    path: std.ArrayListUnmanaged(*MazeGenerator.Cell),

    const AStarEntry = struct {
        priority: i32,
        vertex: i32,
    };

    fn compareEntry(_: void, a: AStarEntry, b: AStarEntry) std.math.Order {
        return std.math.order(a.priority, b.priority);
    }

    const AStarQueue = std.PriorityQueue(AStarEntry, void, compareEntry);

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeAStar {
        const w = helper.config_i64("Maze::AStar", "w");
        const h = helper.config_i64("Maze::AStar", "h");
        const self = try allocator.create(MazeAStar);
        self.* = MazeAStar{
            .allocator = allocator,
            .helper = helper,
            .width = @intCast(w),
            .height = @intCast(h),
            .result_val = 0,
            .maze = try MazeGenerator.Maze.init(allocator, helper, @intCast(w), @intCast(h)),
            .path = .empty,
        };
        return self;
    }

    pub fn deinit(self: *MazeAStar) void {
        if (self.maze) |m| {
            m.deinit();
        }
        self.path.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeAStar) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Maze::AStar");
    }

    fn heuristic(a: *MazeGenerator.Cell, b: *MazeGenerator.Cell) i32 {
        const dx = if (a.x > b.x) a.x - b.x else b.x - a.x;
        const dy = if (a.y > b.y) a.y - b.y else b.y - a.y;
        return dx + dy;
    }

    fn reconstructPath(self: *MazeAStar, came_from: []const i32, current_idx_in: i32) !std.ArrayListUnmanaged(*MazeGenerator.Cell) {
        var path = std.ArrayListUnmanaged(*MazeGenerator.Cell).empty;
        errdefer path.deinit(self.allocator);

        var current_idx = current_idx_in;
        while (current_idx != -1) {
            const y: i32 = @divTrunc(current_idx, self.width);
            const x: i32 = @rem(current_idx, self.width);
            try path.append(self.allocator, &self.maze.?.cells[@intCast(y)][@intCast(x)]);
            current_idx = came_from[@intCast(current_idx)];
        }

        std.mem.reverse(*MazeGenerator.Cell, path.items);
        return path;
    }

    fn astar(self: *MazeAStar, start: *MazeGenerator.Cell, target: *MazeGenerator.Cell) !std.ArrayListUnmanaged(*MazeGenerator.Cell) {
        if (start == target) {
            var result = std.ArrayListUnmanaged(*MazeGenerator.Cell).empty;
            try result.append(self.allocator, start);
            return result;
        }

        const width = self.width;
        const size: usize = @intCast(width * self.height);

        const start_idx: usize = @intCast(start.y * width + start.x);
        const target_idx: usize = @intCast(target.y * width + target.x);

        const came_from = try self.allocator.alloc(i32, size);
        defer self.allocator.free(came_from);
        @memset(came_from, -1);

        const g_score = try self.allocator.alloc(i32, size);
        defer self.allocator.free(g_score);
        @memset(g_score, std.math.maxInt(i32));

        const best_f = try self.allocator.alloc(i32, size);
        defer self.allocator.free(best_f);
        @memset(best_f, std.math.maxInt(i32));

        var open_set: AStarQueue = .empty;
        defer open_set.deinit(self.allocator);

        g_score[start_idx] = 0;
        const f_start = heuristic(start, target);

        try open_set.push(self.allocator, AStarEntry{ .priority = f_start, .vertex = @intCast(start_idx) });
        best_f[start_idx] = f_start;

        while (open_set.pop()) |entry| {
            const current_idx = entry.vertex;

            if (current_idx == @as(i32, @intCast(target_idx))) {
                return try self.reconstructPath(came_from, current_idx);
            }

            const current_y: i32 = @divTrunc(current_idx, width);
            const current_x: i32 = @rem(current_idx, width);
            const current = &self.maze.?.cells[@intCast(current_y)][@intCast(current_x)];

            const current_g = g_score[@intCast(current_idx)];

            var i: u8 = 0;
            while (i < current.neighbor_count) : (i += 1) {
                const neighbor = current.neighbors[i];
                if (!neighbor.kind.isWalkable()) continue;

                const neighbor_idx: usize = @intCast(neighbor.y * width + neighbor.x);
                const tentative_g = current_g + 1;

                if (tentative_g < g_score[neighbor_idx]) {
                    came_from[neighbor_idx] = current_idx;
                    g_score[neighbor_idx] = tentative_g;
                    const f_new = tentative_g + heuristic(neighbor, target);

                    if (f_new < best_f[neighbor_idx]) {
                        best_f[neighbor_idx] = f_new;
                        try open_set.push(self.allocator, AStarEntry{ .priority = f_new, .vertex = @intCast(neighbor_idx) });
                    }
                }
            }
        }

        return std.ArrayListUnmanaged(*MazeGenerator.Cell).empty;
    }

    fn midCellChecksum(path: std.ArrayListUnmanaged(*MazeGenerator.Cell)) u32 {
        if (path.items.len == 0) return 0;
        const cell = path.items[path.items.len / 2];
        return @intCast(cell.x * cell.y);
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            self.path.deinit(self.allocator);
            self.path = self.astar(m.start, m.finish) catch return;
            self.result_val +%= @intCast(self.path.items.len);
        }
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        self.maze.?.generate() catch return;
        self.result_val = 0;
        self.path = .empty;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        return self.result_val +% midCellChecksum(self.path);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
