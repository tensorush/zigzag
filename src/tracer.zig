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
    const screen_side = @as(f64, config.SCREEN_SIDE_LEN);
    const x_direction = vector.Vec4{ cur_camera.field_of_view, 0.0, 0.0 };
    const y_direction = vector.normalize(vector.crossProduct(x_direction, cur_camera.direction)) * @splat(config.VECTOR_LEN, cur_camera.field_of_view);
    const ray_origin = vector.Vec4{ 50.0, 52.0, 295.6 };
    var chunk_samples: [config.NUM_SAMPLES_PER_PIXEL * config.NUM_SCREEN_DIMS]f64 = undefined;
    var sphere_samples: [config.NUM_SAMPLES_PER_PIXEL * config.NUM_SCREEN_DIMS]f64 = undefined;
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = &prng.random();
    camera.samplePixels(&chunk_samples, rng);
    camera.applyTentFilter(&chunk_samples);
    const inverse_num_samples_per_pixel = @splat(config.VECTOR_LEN, 1.0 / @as(f64, config.NUM_SAMPLES_PER_PIXEL));
    const start_x = offset % config.SCREEN_SIDE_LEN;
    const start_y = offset / config.SCREEN_SIDE_LEN;
    var y = start_y;
    var x = start_x;
    var pixel_offset = offset * config.VECTOR_LEN;
    const end_offset = pixel_offset + size * config.VECTOR_LEN;
    const ray_scale = @splat(config.VECTOR_LEN, @as(f64, 136.0));
    while (pixel_offset < end_offset) : (pixel_offset += config.VECTOR_LEN) {
        camera.samplePixels(&sphere_samples, rng);
        var anti_aliased_color = vector.ZERO_VECTOR;
        var anti_aliasing_factor: usize = 0;
        while (anti_aliasing_factor < config.ANTI_ALIASING_FACTOR) : (anti_aliasing_factor += 1) {
            var raw_color = vector.ZERO_VECTOR;
            const X_ANTI_ALIASING_FACTOR = @intToFloat(f64, (anti_aliasing_factor & 1));
            const Y_ANTI_ALIASING_FACTOR = @intToFloat(f64, (anti_aliasing_factor >> 1));
            var sample_idx: usize = 0;
            while (sample_idx < config.NUM_SAMPLES_PER_PIXEL) : (sample_idx += 1) {
                const x_chunk = chunk_samples[sample_idx * config.NUM_SCREEN_DIMS];
                const y_chunk = chunk_samples[sample_idx * config.NUM_SCREEN_DIMS + 1];
                const x_chunk_direction = x_direction * @splat(config.VECTOR_LEN, (((X_ANTI_ALIASING_FACTOR + 0.5 + x_chunk) / 2.0) + @intToFloat(f64, x)) / screen_side - 0.5);
                const y_chunk_direction = y_direction * @splat(config.VECTOR_LEN, -((((Y_ANTI_ALIASING_FACTOR + 0.5 + y_chunk) / 2.0) + @intToFloat(f64, y)) / screen_side - 0.5));
                var ray_direction = vector.normalize(x_chunk_direction + y_chunk_direction + cur_camera.direction);
                var cur_ray = ray.Ray{ .origin = ray_origin + ray_direction * ray_scale, .direction = ray_direction };
                const x_sphere_sample = sphere_samples[sample_idx * config.NUM_SCREEN_DIMS];
                const y_sphere_sample = sphere_samples[sample_idx * config.NUM_SCREEN_DIMS + 1];
                const ray_color = ray.tracePath(cur_ray, tracer.scene, x_sphere_sample, y_sphere_sample, tracer.samples, rng);
                raw_color += ray_color * inverse_num_samples_per_pixel;
            }
            anti_aliased_color += raw_color * vector.INVERSE_ANTI_ALIASING_FACTOR;
        }
        var color = image.getColor(anti_aliased_color);
        pixels[pixel_offset + 0] = color[0];
        pixels[pixel_offset + 1] = color[1];
        pixels[pixel_offset + 2] = color[2];
        x += 1;
        if (x == config.SCREEN_SIDE_LEN) {
            x = 0;
            y += 1;
        }
    }
}
