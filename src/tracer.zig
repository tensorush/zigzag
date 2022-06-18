const std = @import("std");
const ray = @import("ray.zig");
const image = @import("image.zig");
const scene = @import("scene.zig");
const camera = @import("camera.zig");
const Config = @import("Config.zig");
const Vector = @import("Vector.zig");

pub const Tracer = struct {
    samples: [Config.SAMPLES_PER_PIXEL * Config.SCREEN_DIMS]f64 = undefined,
    scene: *scene.Scene,
};

pub fn tracePaths(tracer: Tracer, buffer: []u8, offset: usize, size: usize) !void {
    const cur_camera = tracer.scene.camera;
    const screen_side = @as(f64, Config.SCREEN_SIDE);
    const x_direction = Vector.Vec3{ cur_camera.field_of_view, 0.0, 0.0 };
    const y_direction = Vector.normalize(Vector.crossProduct(x_direction, cur_camera.direction)) * @splat(Config.SCENE_DIMS, cur_camera.field_of_view);
    const ray_origin = Vector.Vec3{ 50.0, 52.0, 295.6 };
    var chunk_samples: [Config.SAMPLES_PER_PIXEL * Config.SCREEN_DIMS]f64 = undefined;
    var sphere_samples: [Config.SAMPLES_PER_PIXEL * Config.SCREEN_DIMS]f64 = undefined;
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = &prng.random();
    camera.samplePixels(&chunk_samples, rng);
    camera.applyTentFilter(&chunk_samples);
    const inverse_samples_per_pixel = @splat(Config.SCENE_DIMS, 1.0 / @as(f64, Config.SAMPLES_PER_PIXEL));
    const start_x = offset % Config.SCREEN_SIDE;
    const start_y = offset / Config.SCREEN_SIDE;
    var y = start_y;
    var x = start_x;
    var pixel_offset = offset * Config.NUM_CHANNELS;
    const end_offset = pixel_offset + size * Config.NUM_CHANNELS;
    const ray_scale = @splat(Config.SCENE_DIMS, @as(f64, 136.0));
    while (pixel_offset < end_offset) : (pixel_offset += Config.NUM_CHANNELS) {
        camera.samplePixels(&sphere_samples, rng);
        var anti_aliased_color = Vector.ZERO_VECTOR;
        var anti_aliasing_factor: usize = 0;
        while (anti_aliasing_factor < Config.ANTI_ALIASING_FACTOR) : (anti_aliasing_factor += 1) {
            var raw_color = Vector.ZERO_VECTOR;
            const X_ANTI_ALIASING_FACTOR = @intToFloat(f64, (anti_aliasing_factor & 1));
            const Y_ANTI_ALIASING_FACTOR = @intToFloat(f64, (anti_aliasing_factor >> 1));
            var sample_idx: usize = 0;
            while (sample_idx < Config.SAMPLES_PER_PIXEL) : (sample_idx += 1) {
                const x_chunk = chunk_samples[sample_idx * Config.SCREEN_DIMS];
                const y_chunk = chunk_samples[sample_idx * Config.SCREEN_DIMS + 1];
                const x_chunk_direction = x_direction * @splat(Config.SCENE_DIMS, (((X_ANTI_ALIASING_FACTOR + 0.5 + x_chunk) / 2.0) + @intToFloat(f64, x)) / screen_side - 0.5);
                const y_chunk_direction = y_direction * @splat(Config.SCENE_DIMS, -((((Y_ANTI_ALIASING_FACTOR + 0.5 + y_chunk) / 2.0) + @intToFloat(f64, y)) / screen_side - 0.5));
                var ray_direction = Vector.normalize(x_chunk_direction + y_chunk_direction + cur_camera.direction);
                var cur_ray = ray.Ray{ .origin = ray_origin + ray_direction * ray_scale, .direction = ray_direction };
                const x_sphere_sample = sphere_samples[sample_idx * Config.SCREEN_DIMS];
                const y_sphere_sample = sphere_samples[sample_idx * Config.SCREEN_DIMS + 1];
                const ray_color = ray.tracePath(cur_ray, tracer.scene, x_sphere_sample, y_sphere_sample, tracer.samples, rng);
                raw_color += ray_color * inverse_samples_per_pixel;
            }
            anti_aliased_color += raw_color * Vector.INVERSE_ANTI_ALIASING_FACTOR;
        }
        var color = image.getColor(anti_aliased_color);
        buffer[pixel_offset + 3] = 0;
        buffer[pixel_offset + 0] = @intCast(u8, color[0]);
        buffer[pixel_offset + 1] = @intCast(u8, color[1]);
        buffer[pixel_offset + 2] = @intCast(u8, color[2]);
        x += 1;
        if (x == Config.SCREEN_SIDE) {
            x = 0;
            y += 1;
        }
    }
}
