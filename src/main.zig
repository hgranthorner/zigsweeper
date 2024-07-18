const std = @import("std");
const g = @import("game.zig");
const b = @import("board.zig");
const rl = @import("raylib.zig");
const render = @import("render.zig");

const TilePosition = struct {
    tile: g.Tile,
    pos: g.Position,
};

const board_side_in_tiles = b.LARGEST_BOARD_SIDE;
const width = 800;
const height = 600;
const total_side_padding = 20;
const top_padding = 30;
const half_side_padding = total_side_padding / 2;
const bottom_padding = half_side_padding;
const play_width = width - total_side_padding;
const play_height = height - (top_padding + bottom_padding);
const playable_area = rl.Vector4{
    .x = half_side_padding,
    .y = top_padding,
    .w = play_width,
    .z = play_height,
};
const tile_width = play_width / board_side_in_tiles;
const tile_height = play_height / board_side_in_tiles;
const font_size = 20;

const DifficultyBox = struct {
    difficulty: g.Difficulty,
    text: []const u8,
    rect: rl.Rectangle,
};
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

    var screen = render.Screen{
        .padding = render.Padding{
            .top = top_padding,
            .bottom = bottom_padding,
            .left = half_side_padding,
            .right = half_side_padding,
        },
        .playable_area = playable_area,
        .tile_width = tile_width,
        .tile_height = tile_height,
        .font_size = font_size,
        .mouse = rl.Vector2Zero(),
    };

    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_Q)) rl.CloseWindow();
        if (rl.IsKeyPressed(rl.KEY_R)) game.state = .choosing_difficulty;
        screen.mouse = rl.GetMousePosition();
        const mouse_delta = rl.GetMouseDelta();

        if (rl.Vector2Equals(mouse_delta, rl.Vector2Zero()) == 0) {
            for (0..board.tiles.len) |i| {
                board.tiles[i].hovered = false;
            }
            if (render.getHoveredPosition(screen)) |pos| {
                if (board.get(pos.x, pos.y)) |t| {
                    var tile = t;
                    tile.hovered = true;
                    board.set(pos.x, pos.y, tile) orelse unreachable;
                }
            }
        }

        switch (game.state) {
            .playing => {
                if (rl.IsKeyPressed(rl.KEY_R)) {
                    game.state = .choosing_difficulty;
                }
                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                    if (render.getHoveredPosition(screen)) |pos| {
                        if (board.uncover(pos.x, pos.y)) |state| {
                            game.state = state;
                            std.debug.print("New state: {any}\n", .{state});
                        }
                    }
                }

                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
                    if (render.getHoveredPosition(screen)) |pos| {
                        if (board.flag(pos.x, pos.y)) |state| {
                            game.state = state;
                            std.debug.print("New state: {any}\n", .{state});
                        } else if (board.uncoverSurrounding(pos.x, pos.y)) |state| {
                            game.state = state;
                            std.debug.print("New state: {any}\n", .{state});
                        }
                    }
                }
            },
            .choosing_difficulty => {
                if (!std.meta.eql(mouse_delta, rl.Vector2Zero())) {
                    for (diff_boxes) |box| {
                        if (rl.CheckCollisionPointRec(screen.mouse, box.rect)) {
                            game.selected_difficulty = box.difficulty;
                        }
                    }
                }
                if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                    for (diff_boxes) |box| {
                        if (rl.CheckCollisionPointRec(screen.mouse, box.rect)) {
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
                        try render.drawTile(screen, &board, ix, iy);
                    }
                }
                try render.drawStatusBar(screen, &board);
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

test {
    std.testing.refAllDecls(@This());
}
