const std = @import("std");
const config = @import("config.zig");
const vector = @import("vector.zig");

pub const Color = @Vector(config.NUM_COLOR_CHANNELS, u8);

pub fn createImage(pixels: []const u8) (std.fs.File.OpenError || std.os.WriteError)!void {
    const image_file = try std.fs.cwd().createFile(config.IMAGE_FILE_PATH, .{});
    defer image_file.close();
    var buf_writer = std.io.bufferedWriter(image_file.writer());
    const writer = buf_writer.writer();
    try writer.print("P3\n{d} {d} {d}\n", .{ config.SCREEN_SIDE_LEN, config.SCREEN_SIDE_LEN, config.NUM_COLORS });
    for (pixels, 1..) |pixel, i| {
        if (i % 4 == 0) {
            try writer.writeAll("\n");
        } else {
            try writer.print("{d} ", .{pixel});
        }
    }
    try buf_writer.flush();
}

pub fn getColor(u: vector.Vec4) Color {
    return .{ getColorComponent(u[2]), getColorComponent(u[1]), getColorComponent(u[0]) };
}

fn getColorComponent(x: f64) u8 {
    return @as(u8, @intFromFloat(std.math.pow(f64, std.math.clamp(x, 0.0, 1.0), 0.45) * 255.0 + 0.5));
}
