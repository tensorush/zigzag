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
    samples: [config.SAMPLES_PER_PIXEL * 2]f64,
};

pub fn trace_paths(tracer: Tracer, buffer: []u8, offset: usize, chunk_size: usize) !void {
    const res = @as(f64, config.WIDTH);
    const cur_camera = tracer.scene.camera;
    var cx = Vec3{ cur_camera.fov_scale, 0.0, 0.0 };
    var cy = vector.normalize(vector.cross_product(cx, cur_camera.forward));
    cy = cy * @splat(config.NUM_DIMS, cur_camera.fov_scale);
    const ray_origin = Vec3{ 50.0, 52.0, 295.6 };
    var chunk_samples: [config.SAMPLES_PER_PIXEL * 2]f64 = undefined;
    var sphere_samples: [config.SAMPLES_PER_PIXEL * 2]f64 = undefined;
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = &prng.random();
    camera.sample_pixels(&chunk_samples, rng);
    camera.apply_tent_filter(&chunk_samples);
    const inverse_samples_per_pixel = @splat(config.NUM_DIMS, 1.0 / @as(f64, config.SAMPLES_PER_PIXEL));
    const start_x = offset % config.WIDTH;
    const start_y = offset / config.WIDTH;
    var y = start_y;
    var x = start_x;
    const dir_scale = @splat(config.NUM_DIMS, @as(f64, 136.0));
    var pixel_offset = offset * 4;
    const end_offset = pixel_offset + chunk_size * 4;
    while (pixel_offset < end_offset) : (pixel_offset += 4) {
        camera.sample_pixels(&sphere_samples, rng);
        var cr = config.ZERO_VECTOR;
        var ANTI_ALIASING: usize = 0;
        while (ANTI_ALIASING < config.NUM_ANTI_ALIASING) : (ANTI_ALIASING += 1) {
            var pr = config.ZERO_VECTOR;
            const X_ANTI_ALIASING = @intToFloat(f64, (ANTI_ALIASING & 0x1));
            const Y_ANTI_ALIASING = @intToFloat(f64, (ANTI_ALIASING >> 1));
            var s: usize = 0;
            while (s < config.SAMPLES_PER_PIXEL) : (s += 1) {
                const dx = chunk_samples[s * 2];
                const dy = chunk_samples[s * 2 + 1];
                const px = (((X_ANTI_ALIASING + 0.5 + dx) / 2.0) + @intToFloat(f64, x)) / res - 0.5;
                const py = -((((Y_ANTI_ALIASING + 0.5 + dy) / 2.0) + @intToFloat(f64, y)) / res - 0.5);
                const ccx = cx * @splat(config.NUM_DIMS, px);
                const ccy = cy * @splat(config.NUM_DIMS, py);
                var ray_dir = vector.normalize(ccx + ccy + cur_camera.forward);
                var cur_ray = ray.Ray{ .origin = ray_origin + ray_dir * dir_scale, .dir = ray_dir };
                const uu1 = sphere_samples[s * 2];
                const uu2 = sphere_samples[s * 2 + 1];
                const r = ray.trace_path(cur_ray, tracer.scene, uu1, uu2, tracer.samples, rng);
                pr += r * inverse_samples_per_pixel;
            }
            cr += pr * config.INVERSE_ANTI_ALIASING;
        }
        var col = image.get_color(cr);
        buffer[pixel_offset + 3] = 0xFF;
        buffer[pixel_offset + 0] = @intCast(u8, col[2]);
        buffer[pixel_offset + 1] = @intCast(u8, col[1]);
        buffer[pixel_offset + 2] = @intCast(u8, col[0]);
        x += 1;
        if (x == config.WIDTH) {
            x = 0;
            y += 1;
        }
    }
}
