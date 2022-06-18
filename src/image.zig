const std = @import("std");
const Config = @import("Config.zig");
const Vector = @import("Vector.zig");

pub fn getColorComponent(x: f64) u32 {
    return @floatToInt(u32, std.math.pow(f64, std.math.clamp(x, 0.0, 1.0), 0.45) * 255.0 + 0.5);
}

pub fn getColor(u: Vector.Vec3) std.meta.Vector(3, u32) {
    return .{ getColorComponent(u[0]), getColorComponent(u[1]), getColorComponent(u[2]) };
}

pub fn createImage(pixels: []const u8) !void {
    const image_file = try std.fs.cwd().createFile(Config.IMAGE_FILE_PATH, .{});
    defer image_file.close();
    var writer = std.io.bufferedWriter(image_file.writer()).writer();
    try writer.print("P3\n{} {} {}\n", .{ Config.SCREEN_SIDE, Config.SCREEN_SIDE, Config.NUM_COLORS });
    var channel_idx: usize = 0;
    while (channel_idx < Config.SCREEN_SIDE * Config.SCREEN_SIDE * Config.NUM_CHANNELS) : (channel_idx += Config.NUM_CHANNELS) {
        try writer.print("{} {} {}\n", .{ pixels[channel_idx], pixels[channel_idx + 1], pixels[channel_idx + 2] });
    }
}
