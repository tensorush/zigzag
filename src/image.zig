const std = @import("std");
const config = @import("config.zig");

const Vec3 = config.Vec3;

pub fn getColorComponent(x: f64) u32 {
    return @floatToInt(u32, std.math.pow(f64, std.math.clamp(x, 0.0, 1.0), 0.45) * 255.0 + 0.5);
}

pub fn getColor(u: Vec3) std.meta.Vector(3, u32) {
    return .{ getColorComponent(u[0]), getColorComponent(u[1]), getColorComponent(u[2]) };
}

pub fn createImage(pixels: []const u8) !void {
    const image_file = try std.fs.cwd().createFile(config.IMAGE_FILE_PATH, .{});
    defer image_file.close();
    var image_file_stream = std.io.bufferedWriter(image_file.writer()).writer();
    try image_file_stream.print("P3\n{} {} {}\n", .{ config.SCREEN_SIDE, config.SCREEN_SIDE, config.NUM_COLORS });
    var channel_idx: usize = 0;
    while (channel_idx < config.SCREEN_SIDE * config.SCREEN_SIDE * config.NUM_CHANNELS) : (channel_idx += config.NUM_CHANNELS) {
        try image_file_stream.print("{} {} {}\n", .{ pixels[channel_idx], pixels[channel_idx + 1], pixels[channel_idx + 2] });
    }
}
