const std = @import("std");
const config = @import("config.zig");
const vector = @import("vector.zig");

pub fn createImage(pixels: []const u8) (std.fs.File.OpenError || std.os.WriteError)!void {
    const image_file = try std.fs.cwd().createFile(config.IMAGE_FILE_PATH, .{});
    defer image_file.close();
    var writer = std.io.bufferedWriter(image_file.writer()).writer();
    try writer.print("P3\n{} {} {}\n", .{ config.SCREEN_SIDE_LEN, config.SCREEN_SIDE_LEN, config.NUM_COLORS });
    var channel_idx: usize = 0;
    while (channel_idx < config.SCREEN_SIDE_LEN * config.SCREEN_SIDE_LEN * config.VECTOR_LEN) : (channel_idx += config.VECTOR_LEN) {
        try writer.print("{} {} {}\n", .{ pixels[channel_idx], pixels[channel_idx + 1], pixels[channel_idx + 2] });
    }
}

pub fn getColor(u: vector.Vec4) std.meta.Vector(config.NUM_COLOR_CHANNELS, u8) {
    return .{ getColorComponent(u[2]), getColorComponent(u[1]), getColorComponent(u[0]) };
}

fn getColorComponent(x: f64) u8 {
    return @floatToInt(u8, std.math.pow(f64, std.math.clamp(x, 0.0, 1.0), 0.45) * 255.0 + 0.5);
}
