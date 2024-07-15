const std = @import("std");

pub const Position = struct {
    x: i32,
    y: i32,
};

pub const TileTag = enum { mine, value };
pub const TileType = union(TileTag) { mine: void, value: u8 };
pub const Tile = struct {
    type: TileType,
    flag: bool,
    uncovered: bool,

    pub fn mine() Tile {
        return Tile{
            .flag = false,
            .type = TileTag.mine,
            .uncovered = false,
        };
    }

    pub fn value(val: u8) Tile {
        return Tile{
            .flag = false,
            .type = .{ .value = val },
            .uncovered = false,
        };
    }
};

pub const DifficultyTag = enum {
    easy,
    medium,
    hard,
};
pub const Difficulty = union(DifficultyTag) {
    easy: void,
    medium: void,
    hard: void,

    pub fn numMines(self: Difficulty, board_size: usize) usize {
        const sqrt = std.math.sqrt(board_size);
        return switch (self) {
            Difficulty.easy => sqrt,
            Difficulty.medium => sqrt * 2,
            Difficulty.hard => sqrt * 3,
        };
    }

    pub fn toString(self: Difficulty) []const u8 {
        return switch (self) {
            Difficulty.easy => "Easy",
            Difficulty.medium => "Medium",
            Difficulty.hard => "Hard",
        };
    }
};

pub const GameState = union(enum) {
    choosing_difficulty: void,
    playing: void,
    won: void,
    lost: void,
};

pub const Game = struct {
    state: GameState,
    selected_difficulty: Difficulty,

    pub fn init(starting_state: GameState) Game {
        return Game{ .state = starting_state, .selected_difficulty = .easy };
    }
};
