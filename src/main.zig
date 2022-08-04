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

pub fn main() (std.mem.Allocator.Error || std.os.GetRandomError || std.Thread.CpuCountError || std.Thread.SpawnError || std.fs.File.OpenError || std.os.WriteError || error{TimedOut})!void {
    // Allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // Camera
    const field_of_view = std.math.tan(@as(f64, 55.0 * std.math.pi / 180.0 * 0.5));
    var cur_camera = camera.Camera{ .direction = vector.createUnitVector(0.0, -0.042612, -1.0), .field_of_view = field_of_view };
    // Materials
    const diffuse_black = material.Material{};
    const diffuse_grey = material.Material{ .diffuse = .{ 0.75, 0.75, 0.75 } };
    const diffuse_red = material.Material{ .diffuse = .{ 0.95, 0.15, 0.15 } };
    const diffuse_blue = material.Material{ .diffuse = .{ 0.25, 0.25, 0.7 } };
    const white_light = material.Material{ .emissive = @splat(config.VECTOR_LEN, @as(f64, 10)) };
    const mirror = material.Material{ .material_type = material.MaterialType.MIRROR, .diffuse = @splat(config.VECTOR_LEN, @as(f64, 0.99)) };
    const glossy_white = material.Material{ .material_type = material.MaterialType.GLOSSY, .diffuse = .{ 0.3, 0.05, 0.05 }, .specular = @splat(config.VECTOR_LEN, @as(f64, 0.69)), .specular_exponent = 45.0 };
    // Scene
    var cornell_box = scene.Scene{ .objects = try std.ArrayList(sphere.Sphere).initCapacity(allocator, 16), .lights = try std.ArrayList(usize).initCapacity(allocator, 16), .camera = &cur_camera };
    try cornell_box.objects.append(sphere.makeSphere(16.5, .{ 76.0, 16.5, 78.0 }, &mirror));
    try cornell_box.objects.append(sphere.makeSphere(1e5, .{ 50.0, 1e5, 81.6 }, &diffuse_grey));
    try cornell_box.objects.append(sphere.makeSphere(1e5, .{ 50.0, 40.8, 1e5 }, &diffuse_grey));
    try cornell_box.objects.append(sphere.makeSphere(10.5, .{ 50.0, 65.1, 81.6 }, &white_light));
    try cornell_box.objects.append(sphere.makeSphere(16.5, .{ 27.0, 16.5, 57.0 }, &glossy_white));
    try cornell_box.objects.append(sphere.makeSphere(1e5, .{ 1e5 + 1.0, 40.8, 81.6 }, &diffuse_red));
    try cornell_box.objects.append(sphere.makeSphere(1e5, .{ 50.0, -1e5 + 81.6, 81.6 }, &diffuse_grey));
    try cornell_box.objects.append(sphere.makeSphere(1e5, .{ -1e5 + 99.0, 40.8, 81.6 }, &diffuse_blue));
    try cornell_box.objects.append(sphere.makeSphere(1e5, .{ 50.0, 40.8, -1e5 + 170.0 }, &diffuse_black));
    try cornell_box.collectLights();
    // Path tracer
    var cur_tracer = tracer.Tracer{ .scene = &cornell_box };
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = &prng.random();
    camera.samplePixels(&cur_tracer.samples, rng);
    // Framebuffer
    var framebuffer = std.ArrayList(u8).init(allocator);
    try framebuffer.appendNTimes(0, config.SCREEN_SIDE_LEN * config.SCREEN_SIDE_LEN * config.VECTOR_LEN);
    // Cores
    const num_cores = try std.Thread.getCpuCount();
    std.debug.print("Found {} CPU cores\n", .{num_cores});
    // Workers
    var num_workers = num_cores;
    var worker_data = try std.ArrayList(worker.Worker).initCapacity(allocator, num_workers);
    var threads = try std.ArrayList(std.Thread).initCapacity(allocator, num_workers);
    var done_count = std.atomic.Atomic(u32).init(0);
    var work_queue = std.atomic.Queue(worker.WorkChunk).init();
    // Multi-threaded preparation
    if (config.IS_MULTI_THREADED) {
        var worker_idx: usize = 0;
        while (worker_idx < num_workers) : (worker_idx += 1) {
            worker_data.appendAssumeCapacity(.{ .done_count = &done_count, .queue = &work_queue });
            threads.appendAssumeCapacity(try std.Thread.spawn(.{}, worker.Worker.launch, .{&worker_data.items[worker_idx]}));
        }
    }
    // Execution
    const NUM_CHUNKS = config.SCREEN_SIDE_LEN * config.SCREEN_SIDE_LEN / config.CHUNK_SIZE;
    const start_time = std.time.milliTimestamp();
    if (config.IS_MULTI_THREADED) {
        var chunk_idx: usize = 0;
        var thread_idx: usize = 0;
        while (chunk_idx < NUM_CHUNKS) : (chunk_idx += 1) {
            const node = try allocator.create(std.atomic.Queue(worker.WorkChunk).Node);
            node.* = .{ .prev = undefined, .next = undefined, .data = .{ .tracer = &cur_tracer, .buffer = &framebuffer.items, .offset = chunk_idx * config.CHUNK_SIZE, .size = config.CHUNK_SIZE } };
            worker_data.items[thread_idx].put(node);
            thread_idx = (thread_idx + 1) % num_workers;
        }
    } else {
        try tracer.tracePaths(cur_tracer, framebuffer.items, 0, config.SCREEN_SIDE_LEN * config.SCREEN_SIDE_LEN);
    }
    try worker.waitUntilDone(&done_count, NUM_CHUNKS);
    // Time
    const time_taken = std.time.milliTimestamp() - start_time;
    std.debug.print("Took {d} seconds\n", .{@intToFloat(f64, time_taken) / 1000.0});
    // Image
    try image.createImage(framebuffer.items);
    for (threads.items) |thread, idx| {
        worker.joinThread(thread, &worker_data.items[idx]);
    }
}
