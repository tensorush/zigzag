const std = @import("std");
const image = @import("image.zig");
const scene = @import("scene.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const sphere = @import("sphere.zig");
const tracer = @import("tracer.zig");
const vector = @import("vector.zig");
const worker = @import("worker.zig");
const material = @import("material.zig");

const Vec3 = config.Vec3;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // Set up scene
    const fov_scale = std.math.tan(@as(f64, 55.0 * std.math.pi / 180.0 * 0.5));
    var cur_camera = camera.Camera{ .forward = vector.new_normal(0.0, -0.042612, -1.0), .fov_scale = fov_scale };
    const white = @splat(config.NUM_DIMS, @as(f64, 0.99));
    const diffuse_grey = material.Material{ .diffuse = .{ 0.75, 0.75, 0.75 } };
    const diffuse_red = material.Material{ .diffuse = .{ 0.95, 0.15, 0.15 } };
    const diffuse_blue = material.Material{ .diffuse = .{ 0.25, 0.25, 0.7 } };
    const diffuse_black = material.Material{};
    const glossy_white = material.Material{ .material_type = material.MaterialType.GLOSSY, .diffuse = .{ 0.3, 0.05, 0.05 }, .specular = @splat(config.NUM_DIMS, @as(f64, 0.69)), .exp = 45.0 };
    const white_light = material.Material{ .emissive = @splat(config.NUM_DIMS, @as(f64, 10)) };
    const mirror = material.Material{ .material_type = material.MaterialType.MIRROR, .diffuse = white };
    var cornell_box = scene.Scene{ .objects = try std.ArrayList(sphere.Sphere).initCapacity(allocator, 16), .lights = try std.ArrayList(usize).initCapacity(allocator, 16), .camera = &cur_camera };
    try cornell_box.objects.append(sphere.make_sphere(1e5, .{ 1e5 + 1.0, 40.8, 81.6 }, &diffuse_red));
    try cornell_box.objects.append(sphere.make_sphere(1e5, .{ -1e5 + 99.0, 40.8, 81.6 }, &diffuse_blue));
    try cornell_box.objects.append(sphere.make_sphere(1e5, .{ 50.0, 40.8, 1e5 }, &diffuse_grey));
    try cornell_box.objects.append(sphere.make_sphere(1e5, .{ 50.0, 40.8, -1e5 + 170.0 }, &diffuse_black));
    try cornell_box.objects.append(sphere.make_sphere(1e5, .{ 50.0, 1e5, 81.6 }, &diffuse_grey));
    try cornell_box.objects.append(sphere.make_sphere(1e5, .{ 50.0, -1e5 + 81.6, 81.6 }, &diffuse_grey));
    try cornell_box.objects.append(sphere.make_sphere(16.5, .{ 27.0, 16.5, 57.0 }, &glossy_white));
    try cornell_box.objects.append(sphere.make_sphere(16.5, .{ 76.0, 16.5, 78.0 }, &mirror));
    try cornell_box.objects.append(sphere.make_sphere(10.5, .{ 50.0, 65.1, 81.6 }, &white_light));
    try cornell_box.collect_lights();
    // Set up path tracer
    var cur_tracer = tracer.Tracer{ .scene = &cornell_box, .samples = undefined };
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = &prng.random();
    camera.sample_pixels(&cur_tracer.samples, rng);
    // Set up framebuffer
    var framebuffer = std.ArrayList(u8).init(allocator);
    try framebuffer.appendNTimes(0, config.NUM_PIXELS * 4);
    const num_cores = try std.Thread.getCpuCount();
    std.debug.print("Found {} CPU cores\n", .{num_cores});
    // Set up workers
    var num_workers = num_cores;
    var worker_data = try std.ArrayList(worker.WorkerThreadData).initCapacity(allocator, num_workers);
    var threads = try std.ArrayList(std.Thread).initCapacity(allocator, num_workers);
    var done_count = std.atomic.Atomic(u32).init(0);
    var work_queue = std.atomic.Queue(worker.WorkItem).init();
    // Set up multi-threaded execution
    if (config.IS_MULTI_THREADED) {
        var i: usize = 0;
        while (i < num_workers) : (i += 1) {
            worker_data.appendAssumeCapacity(.{ .done_count = &done_count, .queue = &work_queue });
            threads.appendAssumeCapacity(try std.Thread.spawn(.{}, worker.worker_thread, .{&worker_data.items[i]}));
        }
    }
    // Start execution
    const chunk_size: usize = 256;
    const num_chunks = config.NUM_PIXELS / chunk_size;
    const start_time = std.time.milliTimestamp();
    if (config.IS_MULTI_THREADED) {
        var chunk_i: usize = 0;
        var thread_i: usize = 0;
        while (chunk_i < num_chunks) : (chunk_i += 1) {
            const node = allocator.create(std.atomic.Queue(worker.WorkItem).Node) catch unreachable;
            node.* = .{ .prev = undefined, .next = undefined, .data = .{ .tracer = &cur_tracer, .buffer = &framebuffer.items, .offset = chunk_i * chunk_size, .chunk_size = chunk_size } };
            worker_data.items[thread_i].push_job_and_wake(node);
            thread_i = (thread_i + 1) % num_workers;
        }
    } else {
        try tracer.trace_paths(cur_tracer, framebuffer.items, 0, config.NUM_PIXELS);
    }
    try worker.wait_until_done(&done_count, num_chunks);
    const time_taken = std.time.milliTimestamp() - start_time;
    std.debug.print("Took {d} seconds\n", .{@intToFloat(f64, time_taken) / 1000.0});
    // Write framebuffer to file
    try image.create_ppm(framebuffer.items);
    for (threads.items) |thread, index| {
        worker.join_thread(thread, &worker_data.items[index]);
    }
}
