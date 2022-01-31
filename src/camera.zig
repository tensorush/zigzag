const std = @import("std");
const config = @import("config.zig");

const Vec3 = config.Vec3;

pub const Camera = struct {
    field_of_view: f64,
    direction: Vec3,
};

pub fn samplePixels(samples: *[config.SAMPLES_PER_PIXEL * config.SCREEN_DIMS]f64, rng: *std.rand.Random) void {
    const samples_per_pixel = @as(f64, config.SAMPLES_PER_PIXEL);
    const x_strata = @sqrt(samples_per_pixel);
    const y_strata = samples_per_pixel / x_strata;
    var x_step: f64 = 0.0;
    var y_step: f64 = 0.0;
    var sample_idx: usize = 0;
    while (y_step < y_strata) : (y_step += 1.0) {
        while (x_step < x_strata) : (x_step += 1.0) {
            samples[sample_idx] = (x_step + rng.float(f64)) / x_strata;
            samples[sample_idx + 1] = (y_step + rng.float(f64)) / y_strata;
            sample_idx += 2;
        }
        x_step = 0.0;
    }
}

pub fn applyTentFilter(samples: *[config.SAMPLES_PER_PIXEL * config.SCREEN_DIMS]f64) void {
    var x_2: f64 = undefined;
    var y_2: f64 = undefined;
    var sample_idx: usize = 0;
    while (sample_idx < config.SAMPLES_PER_PIXEL) : (sample_idx += 1) {
        x_2 = samples[sample_idx * config.SCREEN_DIMS] * @as(f64, config.SCREEN_DIMS);
        y_2 = samples[sample_idx * config.SCREEN_DIMS + 1] * @as(f64, config.SCREEN_DIMS);
        samples[sample_idx * config.SCREEN_DIMS] = if (x_2 < 1.0) @sqrt(x_2) - 1.0 else 1.0 - @sqrt(2.0 - x_2);
        samples[sample_idx * config.SCREEN_DIMS + 1] = if (y_2 < 1.0) @sqrt(y_2) - 1.0 else 1.0 - @sqrt(2.0 - y_2);
    }
}
