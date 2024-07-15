const std = @import("std");
const g = @import("game.zig");
const Tile = g.Tile;
const TileTag = g.TileTag;
const Difficulty = g.Difficulty;
const GameState = g.GameState;
const Position = g.Position;

pub const LARGEST_BOARD_SIDE = 9;
pub const LARGEST_BOARD = 9 * 9;

const BoardError = error{
    TestFailed,
};

pub fn Board(comptime square: usize) type {
    const board_size = square * square;
    return struct {
        tiles: [board_size]Tile,
        size: usize,
        difficulty: Difficulty,
        length: usize,

        pub fn init(difficulty: Difficulty) ?@This() {
            var tiles: [board_size]Tile = undefined;
            for (0..board_size) |i| {
                tiles[i] = Tile.value(0);
            }

            var board = Board(square){
                .tiles = tiles,
                .size = board_size,
                .difficulty = difficulty,
                .length = square,
            };
            board.seedMines();
            board.updateValues();
            return board;
        }

        pub fn draw(self: @This()) void {
            var line: [square]u8 = undefined;
            for (0..self.length) |y| {
                for (0..self.length) |x| {
                    const tile = self.get(x, y).?;
                    if (!tile.uncovered) {
                        line[x] = '#';
                    } else {
                        const char = switch (tile.type) {
                            TileTag.mine => 'M',
                            TileTag.value => |value| value + '0',
                        };
                        if (char == '0') {
                            line[x] = '.';
                        } else {
                            line[x] = char;
                        }
                    }
                }
                std.debug.print("{s}\n", .{line});
            }
        }

        pub fn uncover(self: *@This(), x: anytype, y: anytype) ?GameState {
            const initial_tile = self.get(x, y) orelse return null;
            if (initial_tile.uncovered) return null;
            if (initial_tile.type == .mine) {
                return GameState.lost;
            }

            var len: usize = 0;
            var arr: [board_size * board_size]Position = undefined;
            arr[len] = Position{ .x = @intCast(x), .y = @intCast(y) };
            len += 1;

            while (0 < len) {
                const pos = arr[len - 1];
                len -= 1;
                var tile = self.get(pos.x, pos.y).?;
                if (tile.uncovered == true or tile.flag == true) continue;
                switch (tile.type) {
                    .mine => return null,
                    .value => |value| {
                        tile.uncovered = true;
                        self.set(pos.x, pos.y, tile).?;
                        if (value != 0) continue;
                        const poses = @This().getSurroundingPositions(@intCast(pos.x), @intCast(pos.y));
                        for (poses) |p| {
                            const surr_tile = self.get(p.x, p.y);
                            if (surr_tile == null) continue;
                            if (surr_tile.?.type == .value and !surr_tile.?.uncovered) {
                                arr[len] = p;
                                len += 1;
                            }
                        }
                    },
                }
            }
            return null;
        }

        fn seedMines(self: *@This()) void {
            var prng = std.rand.DefaultPrng.init(undefined);
            var random = prng.random();
            const num_mines: usize = self.difficulty.numMines(board_size);

            for (0..num_mines) |_| {
                var mine_index = random.uintAtMost(usize, self.tiles.len - 1);
                while (self.tiles[mine_index].type == TileTag.mine) {
                    mine_index = random.uintAtMost(usize, self.tiles.len - 1);
                }
                self.tiles[mine_index] = Tile.mine();
            }
        }

        fn updateValues(self: *@This()) void {
            var surrounding: [8]Tile = undefined;
            for (0..square) |x| {
                for (0..square) |y| {
                    switch (self.get(x, y).?.type) {
                        TileTag.mine => continue,
                        TileTag.value => {
                            const len = self.getSurroundingTiles(&surrounding, x, y);
                            var num_mines: u8 = 0;
                            for (0..len) |i| {
                                switch (surrounding[i].type) {
                                    TileTag.mine => num_mines += 1,
                                    TileTag.value => {},
                                }
                            }
                            self.set(x, y, Tile.value(num_mines)).?;
                        },
                    }
                }
            }
        }

        /// Accepts an x and a y of any numeric type and finds the corresponding tile.
        pub fn get(self: @This(), x: anytype, y: anytype) ?Tile {
            const index = coordsToIndex(x, y) orelse return null;
            return self.tiles[index];
        }

        pub fn flag(self: *@This(), x: anytype, y: anytype) ?GameState {
            if (self.remainingFlags() == 0) {
                return null;
            }

            if (self.get(x, y)) |const_tile| {
                {
                    var tile = const_tile;
                    if (tile.flag) {
                        tile.flag = false;
                    } else {
                        tile.flag = true;
                    }
                    self.set(x, y, tile).?;
                }

                if (self.remainingFlags() == 0) {
                    for (self.tiles) |tile| {
                        if (tile.flag and tile.type != .mine) {
                            return null;
                        }
                    }

                    return GameState.won;
                }
            }

            return null;
        }

        pub fn set(self: *@This(), x: anytype, y: anytype, tile: Tile) ?void {
            const index = coordsToIndex(x, y) orelse return null;
            self.tiles[index] = tile;
        }

        fn coordsToIndex(x: anytype, y: anytype) ?usize {
            if (x < 0 or y < 0 or square <= x or square <= y) {
                return null;
            }

            const uy: usize = @intCast(y);
            const ux: usize = @intCast(x);
            return uy * square + ux;
        }

        fn indexToCoords(i: usize) Position {
            const y = i / square;
            const x = std.math.mod(i, square);
            return .{ .x = x, .y = y };
        }

        pub fn getSurroundingPositions(x: usize, y: usize) [8]Position {
            const ix: i32 = @intCast(x);
            const iy: i32 = @intCast(y);
            const surrounding_positions: [8]Position = .{
                .{ .x = ix - 1, .y = iy - 1 }, .{ .x = ix, .y = iy - 1 },     .{ .x = ix + 1, .y = iy - 1 },
                .{ .x = ix - 1, .y = iy },     .{ .x = ix + 1, .y = iy },     .{ .x = ix - 1, .y = iy + 1 },
                .{ .x = ix, .y = iy + 1 },     .{ .x = ix + 1, .y = iy + 1 },
            };
            return surrounding_positions;
        }

        pub fn getSurroundingTiles(self: @This(), out: []Tile, x: usize, y: usize) usize {
            if (x < 0 or y < 0 or square <= x or square <= y) {
                return 0;
            }
            const ix: i32 = @intCast(x);
            const iy: i32 = @intCast(y);
            const surrounding_positions: [8]Position = .{
                .{ .x = ix - 1, .y = iy - 1 }, .{ .x = ix, .y = iy - 1 },     .{ .x = ix + 1, .y = iy - 1 },
                .{ .x = ix - 1, .y = iy },     .{ .x = ix + 1, .y = iy },     .{ .x = ix - 1, .y = iy + 1 },
                .{ .x = ix, .y = iy + 1 },     .{ .x = ix + 1, .y = iy + 1 },
            };
            var surrounding_i: usize = 0;
            for (surrounding_positions) |p| {
                out[surrounding_i] = self.get(p.x, p.y) orelse continue;
                surrounding_i += 1;
            }

            return surrounding_i;
        }

        pub fn remainingFlags(self: @This()) i32 {
            var total_flags: i32 = @intCast(self.difficulty.numMines(board_size));
            for (self.tiles) |tile| {
                if (tile.flag) total_flags -= 1;
            }

            std.debug.print("Remaining flags: {d}\n", .{total_flags});

            return total_flags;
        }
    };
}

const t = std.testing;

test "Board init works properly" {
    const length = 3;
    const difficulty: Difficulty = Difficulty.easy;
    const board = Board(length).init(difficulty).?;
    var num_mines: usize = 0;
    for (board.tiles) |tile| {
        switch (tile.type) {
            TileTag.value => {},
            TileTag.mine => {
                num_mines += 1;
            },
        }
    }
    try t.expectEqual(difficulty.numMines(board.size), num_mines);
}

test "Board gets surrounding tiles correctly" {
    const length = 3;
    const board = Board(length){
        .tiles = .{
            Tile.mine(),   Tile.value(0), Tile.value(5),
            Tile.value(3), Tile.value(1), Tile.value(6),
            Tile.value(4), Tile.value(2), Tile.value(7),
        },
        .size = length * length,
        .difficulty = Difficulty.easy,
        .length = length,
    };

    try t.expectEqual(null, board.get(100, 100));
    try t.expectEqual(Tile.value(0), board.get(1, 0));
    try t.expectEqual(Tile.value(4), board.get(0, 2));
    {
        var out: [8]Tile = undefined;
        const len = board.getSurroundingTiles(&out, 0, 0);
        try t.expectEqual(3, len);
        try t.expectEqual(Tile.value(3), out[1]);
    }
    {
        var out: [8]Tile = undefined;
        const len = board.getSurroundingTiles(&out, 1, 1);
        try t.expectEqual(8, len);
        try t.expectEqual(Tile.value(7), out[7]);
    }
    {
        var out: [8]Tile = undefined;
        const len = board.getSurroundingTiles(&out, 2, 1);
        try t.expectEqual(5, len);
        try t.expectEqual(Tile.value(0), out[0]);
    }
}

test "Board tracks remaining flags correctly" {
    var board = Board(LARGEST_BOARD_SIDE).init(Difficulty.hard).?;
    const starting_flags = board.remainingFlags();
    board.tiles[0].flag = true;
    const ending_flags = board.remainingFlags();
    try t.expect(ending_flags == starting_flags - 1);
}
