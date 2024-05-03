const std = @import("std");
const game = @import("game.zig");

pub fn main() !void {
    var board = game.Board(game.LARGEST_BOARD_SIDE).init(game.Difficulty.easy) orelse unreachable;
    board.uncover(1, 1);
    board.draw();
}

test {
    std.testing.refAllDecls(@This());
}
