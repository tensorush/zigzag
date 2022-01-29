const std = @import("std");
const ray = @import("ray.zig");
const image = @import("image.zig");
const scene = @import("scene.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const vector = @import("vector.zig");

const Vec3 = config.Vec3;

pub const Tracer = struct {
    scene: *scene.Scene,
    samples: [config.SAMPLES_PER_PIXEL * config.SCREEN_DIMS]f64,
};

pub fn tracePaths(tracer: Tracer, buffer: []u8, offset: usize, chunk_size: usize) !void {
    const cur_camera = tracer.scene.camera;
    const screen_side = @as(f64, config.SCREEN_SIDE);
    const x_direction = Vec3{ cur_camera.field_of_view, 0.0, 0.0 };
    const y_direction = vector.normalize(vector.cross_product(x_direction, cur_camera.forward)) * @splat(config.SCENE_DIMS, cur_camera.field_of_view);
    const ray_origin = Vec3{ 50.0, 52.0, 295.6 };
    var chunk_samples: [config.SAMPLES_PER_PIXEL * config.SCREEN_DIMS]f64 = undefined;
    var sphere_samples: [config.SAMPLES_PER_PIXEL * config.SCREEN_DIMS]f64 = undefined;
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = &prng.random();
    camera.samplePixels(&chunk_samples, rng);
    camera.applyTentFilter(&chunk_samples);
    const inverse_samples_per_pixel = @splat(config.SCENE_DIMS, 1.0 / @as(f64, config.SAMPLES_PER_PIXEL));
    const start_x = offset % config.SCREEN_SIDE;
    const start_y = offset / config.SCREEN_SIDE;
    var y = start_y;
    var x = start_x;
    var pixel_offset = offset * config.NUM_CHANNELS;
    const end_offset = pixel_offset + chunk_size * config.NUM_CHANNELS;
    const ray_scale = @splat(config.SCENE_DIMS, @as(f64, 136.0));
    while (pixel_offset < end_offset) : (pixel_offset += config.NUM_CHANNELS) {
        camera.samplePixels(&sphere_samples, rng);
        var anti_aliased_color = config.ZERO_VECTOR;
        var anti_aliasing_factor: usize = 0;
        while (anti_aliasing_factor < config.ANTI_ALIASING_FACTOR) : (anti_aliasing_factor += 1) {
            var raw_color = config.ZERO_VECTOR;
            const X_ANTI_ALIASING_FACTOR = @intToFloat(f64, (anti_aliasing_factor & 1));
            const Y_ANTI_ALIASING_FACTOR = @intToFloat(f64, (anti_aliasing_factor >> 1));
            var sample_idx: usize = 0;
            while (sample_idx < config.SAMPLES_PER_PIXEL) : (sample_idx += 1) {
                const x_chunk = chunk_samples[sample_idx * config.SCREEN_DIMS];
                const y_chunk = chunk_samples[sample_idx * config.SCREEN_DIMS + 1];
                const x_chunk_direction = x_direction * @splat(config.SCENE_DIMS, (((X_ANTI_ALIASING_FACTOR + 0.5 + x_chunk) / 2.0) + @intToFloat(f64, x)) / screen_side - 0.5);
                const y_chunk_direction = y_direction * @splat(config.SCENE_DIMS, -((((Y_ANTI_ALIASING_FACTOR + 0.5 + y_chunk) / 2.0) + @intToFloat(f64, y)) / screen_side - 0.5));
                var ray_direction = vector.normalize(x_chunk_direction + y_chunk_direction + cur_camera.forward);
                var cur_ray = ray.Ray{ .origin = ray_origin + ray_direction * ray_scale, .direction = ray_direction };
                const x_sphere_sample = sphere_samples[sample_idx * config.SCREEN_DIMS];
                const y_sphere_sample = sphere_samples[sample_idx * config.SCREEN_DIMS + 1];
                const ray_color = ray.tracePath(cur_ray, tracer.scene, x_sphere_sample, y_sphere_sample, tracer.samples, rng);
                raw_color += ray_color * inverse_samples_per_pixel;
            }
            anti_aliased_color += raw_color * config.INVERSE_ANTI_ALIASING_FACTOR;
        }
        var color = image.getColor(anti_aliased_color);
        buffer[pixel_offset + 3] = 0;
        buffer[pixel_offset + 0] = @intCast(u8, color[0]);
        buffer[pixel_offset + 1] = @intCast(u8, color[1]);
        buffer[pixel_offset + 2] = @intCast(u8, color[2]);
        x += 1;
        if (x == config.SCREEN_SIDE) {
            x = 0;
            y += 1;
        }
    }
}
