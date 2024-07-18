const std = @import("std");
const rl = @import("raylib.zig");
const b = @import("board.zig");
const g = @import("game.zig");

pub const Padding = struct {
    top: u32,
    left: u32,
    right: u32,
    bottom: u32,
};

pub const Screen = struct {
    padding: Padding,
    playable_area: rl.Vector4,
    tile_width: u32,
    tile_height: u32,
    font_size: u32,
    mouse: rl.Vector2,
};

pub fn drawTile(
    screen: Screen,
    board: *b.Board(b.LARGEST_BOARD_SIDE),
    ix: anytype,
    iy: anytype,
) !void {
    const x = ix * screen.tile_width + @as(usize, @intFromFloat(screen.playable_area.x));
    const y = iy * screen.tile_height + @as(usize, @intFromFloat(screen.playable_area.y));
    const rect = rl.Rectangle{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = @floatFromInt(screen.tile_width),
        .height = @floatFromInt(screen.tile_height),
    };

    const tile = board.get(ix, iy).?;
    const color = tileColor(tile);
    rl.DrawRectangleRec(rect, color);
    const center_tile_width = x + @divTrunc(screen.tile_width, 2);
    const center_tile_height = y + @divTrunc(screen.tile_height, 2);

    if (tile.uncovered) {
        switch (tile.type) {
            .value => |value| {
                var buf = std.mem.zeroes([128]u8);
                const st: []const u8 = try std.fmt.bufPrint(&buf, "{d}", .{value});
                const c_ptr: [*c]const u8 = @ptrCast(st);
                const text_width = @as(usize, @intCast(rl.MeasureText(c_ptr, @intCast(screen.font_size))));
                rl.DrawText(
                    c_ptr,
                    @intCast(center_tile_width - @divTrunc(text_width, 2)),
                    @intCast(center_tile_height - @divTrunc(screen.font_size, 2)),
                    20,
                    rl.BLACK,
                );
            },
            else => {},
        }
    } else if (tile.flag) {
        const text_width = @as(usize, @intCast(rl.MeasureText("F", @intCast(screen.font_size))));
        rl.DrawText(
            "F",
            @intCast(center_tile_width - @divTrunc(text_width, 2)),
            @intCast(center_tile_height - (screen.font_size / 2)),
            20,
            rl.RED,
        );
    }

    rl.DrawRectangleLinesEx(rect, 1.0, rl.RED);
}

fn tileColor(tile: g.Tile) rl.Color {
    return if (!tile.uncovered and tile.hovered)
        rl.LIGHTGRAY
    else if (tile.type == .mine)
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

pub fn getHoveredPosition(screen: Screen) ?g.Position {
    if (screen.mouse.x < screen.playable_area.x or screen.playable_area.w < screen.mouse.x or
        screen.mouse.y < screen.playable_area.y or screen.playable_area.z < screen.mouse.y)
    {
        return null;
    }
    // Convert the position to x/y tile value
    const x_int: usize = @intFromFloat(screen.mouse.x);
    const x = @divFloor(x_int - screen.padding.left, screen.tile_width);

    const y_int: usize = @intFromFloat(screen.mouse.y);
    const y = @divFloor(y_int - screen.padding.top, screen.tile_height);
    return .{ .x = @intCast(x), .y = @intCast(y) };
}
