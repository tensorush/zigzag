pub const NUM_COLORS: u32 = 255;
pub const RAY_BIAS: f64 = 0.0005;
pub const IS_MULTI_THREADED = true;
pub const VECTOR_LEN: u32 = 1 << 2;
pub const CHUNK_SIZE: usize = 1 << 8;
pub const NUM_COLOR_CHANNELS: usize = 3;
pub const MIN_NUM_BOUNCES: usize = 1 << 2;
pub const MAX_NUM_BOUNCES: usize = 1 << 3;
pub const NUM_SCREEN_DIMS: usize = 1 << 1;
pub const SCREEN_SIDE_LEN: usize = 1 << 9;
pub const ANTI_ALIASING_FACTOR: usize = 1 << 2;
pub const NUM_SAMPLES_PER_PIXEL: usize = 1 << 8;
pub const IMAGE_FILE_PATH = "images/cornell_box.ppm";
