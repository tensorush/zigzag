const std = @import("std");
const ray = @import("ray.zig");
const image = @import("image.zig");
const scene = @import("scene.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const vector = @import("vector.zig");

pub const Tracer = struct {
    samples: [config.NUM_SAMPLES_PER_PIXEL * config.NUM_SCREEN_DIMS]f64 = undefined,
    scene: *scene.Scene,
};

pub fn tracePaths(tracer: Tracer, pixels: []u8, offset: usize, size: usize) std.os.GetRandomError!void {
    const cur_camera = tracer.scene.camera;
    const ray_factor: vector.Vec4 = @splat(136.0);
    const start_x = offset % config.SCREEN_SIDE_LEN;
    const start_y = offset / config.SCREEN_SIDE_LEN;
    const screen_side = @as(f64, config.SCREEN_SIDE_LEN);
    const ray_origin = vector.Vec4{ 50.0, 52.0, 295.6, 0.0 };
    const x_direction = vector.Vec4{ cur_camera.field_of_view, 0.0, 0.0, 0.0 };
    var y_direction = vector.normalize(vector.crossProduct(x_direction, cur_camera.direction)) * @as(vector.Vec4, @splat(cur_camera.field_of_view));
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = prng.random();
    var chunk_samples: [config.NUM_SAMPLES_PER_PIXEL * config.NUM_SCREEN_DIMS]f64 = undefined;
    var sphere_samples: [config.NUM_SAMPLES_PER_PIXEL * config.NUM_SCREEN_DIMS]f64 = undefined;
    var anti_aliased_color: vector.Vec4 = undefined;
    var x_chunk_direction: vector.Vec4 = undefined;
    var y_chunk_direction: vector.Vec4 = undefined;
    var anti_aliasing_factor: usize = undefined;
    var ray_direction: vector.Vec4 = undefined;
    var raw_color: vector.Vec4 = undefined;
    var ray_color: vector.Vec4 = undefined;
    var color: image.Color = undefined;
    var sample_idx: usize = 0;
    var x = start_x;
    var y = start_y;
    camera.samplePixels(&chunk_samples, rng);
    camera.applyTentFilter(&chunk_samples);
    var pixel_offset = offset * config.VECTOR_LEN;
    const end_offset = pixel_offset + size * config.VECTOR_LEN;
    while (pixel_offset < end_offset) : (pixel_offset += config.VECTOR_LEN) {
        camera.samplePixels(&sphere_samples, rng);
        anti_aliased_color = vector.ZERO_VECTOR;
        anti_aliasing_factor = 0;
        while (anti_aliasing_factor < config.ANTI_ALIASING_FACTOR) : (anti_aliasing_factor += 1) {
            raw_color = vector.ZERO_VECTOR;
            sample_idx = 0;
            while (sample_idx < config.NUM_SAMPLES_PER_PIXEL) : (sample_idx += 1) {
                x_chunk_direction = x_direction * @as(vector.Vec4, @splat((((@as(f64, @floatFromInt((anti_aliasing_factor & 1))) + 0.5 + chunk_samples[sample_idx * config.NUM_SCREEN_DIMS]) / 2.0) + @as(f64, @floatFromInt(x))) / screen_side - 0.5));
                y_chunk_direction = y_direction * @as(vector.Vec4, @splat(-((((@as(f64, @floatFromInt((anti_aliasing_factor >> 1))) + 0.5 + chunk_samples[sample_idx * config.NUM_SCREEN_DIMS + 1]) / 2.0) + @as(f64, @floatFromInt(y))) / screen_side - 0.5)));
                ray_direction = vector.normalize(x_chunk_direction + y_chunk_direction + cur_camera.direction);
                ray_color = ray.tracePath(.{ .direction = ray_direction, .origin = ray_origin + ray_direction * ray_factor }, tracer.scene, sphere_samples[sample_idx * config.NUM_SCREEN_DIMS], sphere_samples[sample_idx * config.NUM_SCREEN_DIMS + 1], tracer.samples, rng);
                raw_color += ray_color * @as(vector.Vec4, @splat(1.0 / @as(f64, config.NUM_SAMPLES_PER_PIXEL)));
            }
            anti_aliased_color += raw_color * vector.INVERSE_ANTI_ALIASING_FACTOR;
        }
        color = image.getColor(anti_aliased_color);
        pixels[pixel_offset] = color[0];
        pixels[pixel_offset + 1] = color[1];
        pixels[pixel_offset + 2] = color[2];
        x += 1;
        if (x == config.SCREEN_SIDE_LEN) {
            x = 0;
            y += 1;
        }
    }
}
