const std = @import("std");
const config = @import("config.zig");

const Vec3 = config.Vec3;

pub const Camera = struct {
    forward: Vec3,
    fov_scale: f64,
};

pub fn sample_pixels(samples: *[config.SAMPLES_PER_PIXEL * 2]f64, rng: *std.rand.Random) void {
    const samples_per_pixel = @as(f64, config.SAMPLES_PER_PIXEL);
    const x_strata = @sqrt(samples_per_pixel);
    const y_strata = samples_per_pixel / x_strata;
    var fx: f64 = undefined;
    var fy: f64 = undefined;
    var x_step: f64 = undefined;
    var y_step: f64 = 0.0;
    var sample_idx: usize = 0;
    while (y_step < y_strata) : (y_step += 1.0) {
        x_step = 0.0;
        while (x_step < x_strata) : (x_step += 1.0) {
            fx = (x_step + rng.float(f64)) / x_strata;
            fy = (y_step + rng.float(f64)) / y_strata;
            samples[sample_idx] = fx;
            samples[sample_idx + 1] = fy;
            sample_idx += 2;
        }
    }
}

pub fn apply_tent_filter(samples: *[config.SAMPLES_PER_PIXEL * 2]f64) void {
    var x_2: f64 = undefined;
    var y_2: f64 = undefined;
    var sample_idx: usize = 0;
    while (sample_idx < config.SAMPLES_PER_PIXEL) : (sample_idx += 1) {
        x_2 = samples[sample_idx * 2] * 2.0;
        y_2 = samples[sample_idx * 2 + 1] * 2.0;
        samples[sample_idx * 2] = if (x_2 < 1.0) @sqrt(x_2) - 1.0 else 1.0 - @sqrt(2.0 - x_2);
        samples[sample_idx * 2 + 1] = if (y_2 < 1.0) @sqrt(y_2) - 1.0 else 1.0 - @sqrt(2.0 - y_2);
    }
}
