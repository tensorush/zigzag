// Module imports
const std = @import("std");

// Global constants
pub const NUM_DIMS: u32 = 3;
pub const NUM_COLORS: u32 = 255;
pub const WIDTH: usize = 1 << 9;
pub const HEIGHT: usize = 1 << 9;
pub const RAY_BIAS: f64 = 0.0005;
pub const IS_MULTI_THREADED = true;
pub const MIN_BOUNCES: usize = 1 << 3;
pub const MAX_BOUNCES: usize = 1 << 4;
pub const NUM_PIXELS: u32 = WIDTH * HEIGHT;
pub const NUM_ANTI_ALIASING: usize = 1 << 2;
pub const SAMPLES_PER_PIXEL: usize = 1 << 8;
pub const IMAGE_FILE_PATH = "images/image.ppm";
pub const ZERO_VECTOR = @splat(NUM_DIMS, @as(f64, 0.0));
pub const IDENTITY_VECTOR = @splat(NUM_DIMS, @as(f64, 1.0));
pub const INVERSE_ANTI_ALIASING = @splat(NUM_DIMS, 1.0 / @as(f64, NUM_ANTI_ALIASING));

// Type definitions
pub const Vec3 = std.meta.Vector(NUM_DIMS, f64);
