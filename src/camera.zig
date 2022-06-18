const std = @import("std");
const Config = @import("Config.zig");
const Vector = @import("Vector.zig");

pub const Camera = struct {
    field_of_view: f64,
    direction: Vector.Vec3,
};

pub fn samplePixels(samples: *[Config.SAMPLES_PER_PIXEL * Config.SCREEN_DIMS]f64, rng: *std.rand.Random) void {
    const samples_per_pixel = @as(f64, Config.SAMPLES_PER_PIXEL);
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

pub fn applyTentFilter(samples: *[Config.SAMPLES_PER_PIXEL * Config.SCREEN_DIMS]f64) void {
    var x2: f64 = undefined;
    var y2: f64 = undefined;
    var sample_idx: usize = 0;
    while (sample_idx < Config.SAMPLES_PER_PIXEL) : (sample_idx += 1) {
        x2 = samples[sample_idx * Config.SCREEN_DIMS] * @as(f64, Config.SCREEN_DIMS);
        y2 = samples[sample_idx * Config.SCREEN_DIMS + 1] * @as(f64, Config.SCREEN_DIMS);
        samples[sample_idx * Config.SCREEN_DIMS] = if (x2 < 1.0) @sqrt(x2) - 1.0 else 1.0 - @sqrt(2.0 - x2);
        samples[sample_idx * Config.SCREEN_DIMS + 1] = if (y2 < 1.0) @sqrt(y2) - 1.0 else 1.0 - @sqrt(2.0 - y2);
    }
}
