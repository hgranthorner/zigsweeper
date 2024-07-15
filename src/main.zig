const std = @import("std");
const g = @import("game.zig");
const rl = @import("raylib.zig");

const TilePosition = struct {
    tile: g.Tile,
    pos: g.Position,
};

const board_side_in_tiles = g.LARGEST_BOARD_SIDE;
const width = 800;
const height = 450;
const padding = 20;
const half_padding = padding / 2;
const play_width = width - padding;
const play_height = height - padding;
const tile_width = play_width / board_side_in_tiles;
const tile_height = play_height / board_side_in_tiles;

pub fn main() !void {
    var board = g.Board(board_side_in_tiles).init(g.Difficulty.easy) orelse unreachable;
    var game = g.Game.init();

    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT | rl.FLAG_VSYNC_HINT);
    rl.InitWindow(width, height, "Minesweeper");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyDown(rl.KEY_Q)) rl.CloseWindow();

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            if (getClickedTile()) |pos| {
                if (board.uncover(pos.x, pos.y)) |state| {
                    game.state = state;
                    std.debug.print("New state: {any}\n", .{state});
                }
            }
        }

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
            if (getClickedTile()) |pos| {
                if (board.flag(pos.x, pos.y)) |state| {
                    game.state = state;
                    std.debug.print("New state: {any}\n", .{state});
                }
            }
        }

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.WHITE);

        for (0..board_side_in_tiles) |ix| {
            for (0..board_side_in_tiles) |iy| {
                try drawTile(&board, ix, iy);
            }
        }
    }
}

fn drawTile(board: *g.Board(board_side_in_tiles), ix: anytype, iy: anytype) !void {
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

fn getClickedTile() ?g.Position {
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
