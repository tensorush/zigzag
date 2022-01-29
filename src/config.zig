// Module imports
const std = @import("std");

// Global constants
pub const SCENE_DIMS: u32 = 3;
pub const NUM_COLORS: u32 = 255;
pub const RAY_BIAS: f64 = 0.0005;
pub const IS_MULTI_THREADED = true;
pub const SCREEN_DIMS: usize = 1 << 1;
pub const MIN_BOUNCES: usize = 1 << 2;
pub const MAX_BOUNCES: usize = 1 << 4;
pub const SCREEN_SIDE: usize = 1 << 9;
pub const NUM_CHANNELS: usize = 1 << 2;
pub const SAMPLES_PER_PIXEL: usize = 1 << 8;
pub const ANTI_ALIASING_FACTOR: usize = 1 << 3;
pub const IMAGE_FILE_PATH = "images/cornell_box.ppm";
pub const ZERO_VECTOR = @splat(SCENE_DIMS, @as(f64, 0.0));
pub const IDENTITY_VECTOR = @splat(SCENE_DIMS, @as(f64, 1.0));
pub const INVERSE_ANTI_ALIASING_FACTOR = @splat(SCENE_DIMS, 1.0 / @as(f64, ANTI_ALIASING_FACTOR));

// Type definitions
pub const Vec3 = std.meta.Vector(SCENE_DIMS, f64);
