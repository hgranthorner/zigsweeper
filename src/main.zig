const std = @import("std");
const game = @import("game.zig");
const rl = @import("raylib.zig");

const board_side_in_tiles = game.LARGEST_BOARD_SIDE;
const width = 800;
const height = 450;
const padding = 20;
const half_padding = padding / 2;
const play_width = width - padding;
const play_height = height - padding;
const tile_width = play_width / board_side_in_tiles;
const tile_height = play_height / board_side_in_tiles;

pub fn main() !void {
    var board = game.Board(board_side_in_tiles).init(game.Difficulty.easy) orelse unreachable;

    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT | rl.FLAG_VSYNC_HINT);
    rl.InitWindow(width, height, "Minesweeper");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyDown(rl.KEY_Q)) rl.CloseWindow();

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            if (getClickedTile()) |pos| {
                board.uncover(pos.x, pos.y);
            }
        }

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
            if (getClickedTile()) |pos| {
                // NOTE(grant): I don't know how to actually get a mutable object here,
                //   so I guess I have to copy it...?
                if (board.get(pos.x, pos.y)) |const_tile| {
                    var tile = const_tile;
                    if (tile.flag) {
                        tile.flag = false;
                    } else {
                        tile.flag = true;
                    }
                    board.set(pos.x, pos.y, tile).?;
                }
            }
        }

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.WHITE);

        for (0..board_side_in_tiles) |ix| {
            const x = ix * tile_width + half_padding;
            for (0..board_side_in_tiles) |iy| {
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

                if (tile.uncovered) {
                    switch (tile.type) {
                        .value => |value| {
                            var buf = std.mem.zeroes([128]u8);
                            const st: []const u8 = try std.fmt.bufPrint(&buf, "{d}", .{value});
                            const c_ptr: [*c]const u8 = @ptrCast(st);
                            rl.DrawText(c_ptr, @intCast(x + padding), @intCast(y + padding), 20, rl.BLACK);
                        },
                        else => {},
                    }
                } else if (tile.flag) {
                    rl.DrawText("F", @intCast(x + padding), @intCast(y + padding), 20, rl.RED);
                }

                rl.DrawRectangleLinesEx(rect, 1.0, rl.RED);
            }
        }
    }
}

fn tileColor(tile: game.Tile) rl.Color {
    return if (tile.type == .mine)
        rl.GOLD
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

fn getClickedTile() ?game.Position {
    const pos = rl.GetMousePosition();
    if (pos.x < half_padding or width - half_padding < pos.x or
        pos.y < half_padding or height - half_padding < pos.y)
    {
        return null;
    }
    // Convert the position to x/y tile value
    // uncover it if it's not uncovered
    const x_int: usize = @intFromFloat(pos.x);
    const x = @divFloor(x_int - half_padding, tile_width);

    const y_int: usize = @intFromFloat(pos.y);
    const y = @divFloor(y_int - half_padding, tile_height);
    return .{ .x = @intCast(x), .y = @intCast(y) };
}
