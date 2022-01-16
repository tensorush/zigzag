const std = @import("std");
const config = @import("config.zig");

const Vec3 = config.Vec3;

pub fn get_color_component(x: f64) u32 {
    return @floatToInt(u32, std.math.pow(f64, std.math.clamp(x, 0.0, 1.0), 0.45) * 255.0 + 0.5);
}

pub fn get_color(v: Vec3) std.meta.Vector(3, u32) {
    return .{ get_color_component(v[0]), get_color_component(v[1]), get_color_component(v[2]) };
}

pub fn create_ppm(pixels: []const u8) !void {
    const image_file = try std.fs.cwd().createFile(config.IMAGE_FILE_PATH, .{});
    defer image_file.close();
    var image_file_stream = std.io.bufferedWriter(image_file.writer()).writer();
    try image_file_stream.print("P3\n{} {} {}\n", .{ config.HEIGHT, config.WIDTH, config.NUM_COLORS });
    var subpixel_idx: usize = 0;
    while (subpixel_idx < config.NUM_PIXELS * 4) : (subpixel_idx += 4) {
        try image_file_stream.print("{} {} {}\n", .{ pixels[subpixel_idx + 2], pixels[subpixel_idx + 1], pixels[subpixel_idx] });
    }
}
