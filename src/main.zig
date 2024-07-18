const std = @import("std");
const g = @import("game.zig");
const b = @import("board.zig");
const rl = @import("raylib.zig");

const TilePosition = struct {
    tile: g.Tile,
    pos: g.Position,
};

const board_side_in_tiles = b.LARGEST_BOARD_SIDE;
const width = 800;
const height = 450;
const padding = 20;
const half_padding = padding / 2;
const play_width = width - padding;
const play_height = height - padding;
const tile_width = play_width / board_side_in_tiles;
const tile_height = play_height / board_side_in_tiles;
const font_size = 20;

const DifficultyBox = struct { difficulty: g.Difficulty, text: []const u8, rect: rl.Rectangle };
const Board = b.Board(board_side_in_tiles);

pub fn main() !void {
    var board: Board = undefined;
    var game = g.Game.init(.choosing_difficulty);

    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT | rl.FLAG_VSYNC_HINT);
    rl.InitWindow(width, height, "Minesweeper");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    var diff_boxes: [3]DifficultyBox = undefined;
    for ([3]g.Difficulty{
        g.Difficulty.easy,
        g.Difficulty.medium,
        g.Difficulty.hard,
    }, 0..) |difficulty, i| {
        const ix: isize = @intCast(i);
        const diff_str = difficulty.toString();
        const text_width = rl.MeasureText(@ptrCast(diff_str), font_size);
        const x = (width / 2) - @divFloor(text_width, 2);
        const y = (height / 2) - (font_size + (20 - (ix * 20)));
        diff_boxes[i] = DifficultyBox{
            .difficulty = difficulty,
            .text = diff_str,
            .rect = .{
                .width = @floatFromInt(text_width),
                .height = font_size,
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
            },
        };
    }
    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_Q)) rl.CloseWindow();
        if (rl.IsKeyPressed(rl.KEY_R)) game.state = .choosing_difficulty;
        const mouse = rl.GetMousePosition();
        const mouse_delta = rl.GetMouseDelta();

        switch (game.state) {
            .playing => {
                if (rl.IsKeyPressed(rl.KEY_R)) {
                    game.state = .choosing_difficulty;
                }
                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                    if (getClickedTile(mouse)) |pos| {
                        if (board.uncover(pos.x, pos.y)) |state| {
                            game.state = state;
                            std.debug.print("New state: {any}\n", .{state});
                        }
                    }
                }

                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
                    if (getClickedTile(mouse)) |pos| {
                        if (board.flag(pos.x, pos.y)) |state| {
                            game.state = state;
                            std.debug.print("New state: {any}\n", .{state});
                        }
                    }
                }
            },
            .choosing_difficulty => {
                if (!std.meta.eql(mouse_delta, rl.Vector2Zero())) {
                    for (diff_boxes) |box| {
                        if (rl.CheckCollisionPointRec(mouse, box.rect)) {
                            game.selected_difficulty = box.difficulty;
                        }
                    }
                }
                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                    for (diff_boxes) |box| {
                        if (rl.CheckCollisionPointRec(mouse, box.rect)) {
                            game.state = .playing;
                            board = Board.init(game.selected_difficulty) orelse unreachable;
                        }
                    }
                }
                if (rl.IsKeyPressed(rl.KEY_DOWN)) {
                    game.selected_difficulty = switch (game.selected_difficulty) {
                        .easy => .medium,
                        .medium => .hard,
                        .hard => .easy,
                    };
                }
                if (rl.IsKeyPressed(rl.KEY_UP)) {
                    game.selected_difficulty = switch (game.selected_difficulty) {
                        .easy => .hard,
                        .medium => .easy,
                        .hard => .medium,
                    };
                }
                if (rl.IsKeyPressed(rl.KEY_ENTER)) {
                    game.state = .playing;
                    board = Board.init(game.selected_difficulty) orelse unreachable;
                }
            },
            .lost => {},
            .won => {},
        }

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.WHITE);

        switch (game.state) {
            .playing => {
                for (0..board.length) |ix| {
                    for (0..board.length) |iy| {
                        try drawTile(&board, ix, iy);
                    }
                }
            },
            .won => {
                const win_width = rl.MeasureText("You win!", font_size);
                rl.DrawText(
                    "You win!",
                    (width / 2) - @divFloor(win_width, 2),
                    (height / 2) - font_size,
                    font_size,
                    rl.BLACK,
                );

                const diff_width = rl.MeasureText("Press R to return to the difficulty select screen", font_size);
                rl.DrawText(
                    "Press R to return to the difficulty select screen",
                    (width / 2) - @divFloor(diff_width, 2),
                    (height / 2) + font_size,
                    font_size,
                    rl.BLACK,
                );
            },
            .choosing_difficulty => {
                for (diff_boxes) |box| {
                    const color = if (std.meta.eql(
                        box.difficulty,
                        game.selected_difficulty,
                    )) rl.RED else rl.BLACK;
                    rl.DrawText(
                        @ptrCast(box.text),
                        @intFromFloat(box.rect.x),
                        @intFromFloat(box.rect.y),
                        font_size,
                        color,
                    );
                }
            },
            .lost => {
                const lose_width = rl.MeasureText("You lose!", font_size);
                rl.DrawText(
                    "You lose!",
                    (width / 2) - @divFloor(lose_width, 2),
                    (height / 2),
                    font_size,
                    rl.BLACK,
                );
            },
        }
    }
}

fn drawTile(board: *Board, ix: anytype, iy: anytype) !void {
    const x = ix * tile_width + half_padding;
    const y = iy * tile_height + half_padding;
    const rect = rl.Rectangle{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = tile_width,
        .height = tile_height,
    };

    const tile = board.get(ix, iy).?;
    const color = tileColor(tile);
    rl.DrawRectangleRec(rect, color);
    const center_tile_width = x + (tile_width / 2);
    const center_tile_height = y + (tile_height / 2);

    if (tile.uncovered) {
        switch (tile.type) {
            .value => |value| {
                var buf = std.mem.zeroes([128]u8);
                const st: []const u8 = try std.fmt.bufPrint(&buf, "{d}", .{value});
                const c_ptr: [*c]const u8 = @ptrCast(st);
                const text_width = @as(usize, @intCast(rl.MeasureText(c_ptr, font_size)));
                rl.DrawText(
                    c_ptr,
                    @intCast(center_tile_width - @divTrunc(text_width, 2)),
                    @intCast(center_tile_height - (font_size / 2)),
                    20,
                    rl.BLACK,
                );
            },
            else => {},
        }
    } else if (tile.flag) {
        const text_width = @as(usize, @intCast(rl.MeasureText("F", font_size)));
        rl.DrawText(
            "F",
            @intCast(center_tile_width - @divTrunc(text_width, 2)),
            @intCast(center_tile_height - (font_size / 2)),
            20,
            rl.RED,
        );
    }

    rl.DrawRectangleLinesEx(rect, 1.0, rl.RED);
}

fn tileColor(tile: g.Tile) rl.Color {
    return if (tile.type == .mine)
        // DEBUG: rl.GOLD
        rl.GRAY
    else if (tile.uncovered)
        rl.WHITE
    else if (tile.type == .value)
        rl.GRAY
    else if (tile.flag)
        rl.BLUE
    else
        unreachable;
}

test {
    std.testing.refAllDecls(@This());
}

fn getClickedTile(mouse: rl.Vector2) ?g.Position {
    if (mouse.x < half_padding or width - half_padding < mouse.x or
        mouse.y < half_padding or height - half_padding < mouse.y)
    {
        return null;
    }
    // Convert the position to x/y tile value
    const x_int: usize = @intFromFloat(mouse.x);
    const x = @divFloor(x_int - half_padding, tile_width);

    const y_int: usize = @intFromFloat(mouse.y);
    const y = @divFloor(y_int - half_padding, tile_height);
    return .{ .x = @intCast(x), .y = @intCast(y) };
}
