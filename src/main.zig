const std = @import("std");
const Scene = @import("Scene.zig");
const Tracer = @import("Tracer.zig");
const vector = @import("vector.zig");
const Worker = @import("Worker.zig");

const IS_MULTI_THREADED = true;
const FRAME_DIM: usize = 1 << 5;
const CHUNK_SIZE: usize = 1 << 7;
const MAX_NUM_CORES: usize = 1 << 3;
const FRAME_SIZE = FRAME_DIM * FRAME_DIM * vector.LEN;
const NUM_CHUNKS = FRAME_DIM * FRAME_DIM / CHUNK_SIZE;

const MainError = std.os.GetRandomError || std.Thread.CpuCountError || std.Thread.SpawnError || std.fs.File.OpenError || std.os.WriteError || std.time.Timer.Error;

pub fn main() MainError!void {
    var tracer = Tracer{ .scene = Scene.initCornellBox() };
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = prng.random();
    Tracer.samplePixels(&tracer.samples, rng);

    const stdout = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(stdout.writer());
    const writer = buf_writer.writer();

    const num_cores = try std.Thread.getCpuCount();
    try writer.print("Number of CPU cores: {d}\n", .{num_cores});
    try buf_writer.flush();

    var threads = std.BoundedArray(std.Thread, MAX_NUM_CORES){};
    var workers = std.BoundedArray(Worker, MAX_NUM_CORES){};
    var frame = std.BoundedArray(u8, FRAME_SIZE){};
    frame.appendNTimesAssumeCapacity(0, FRAME_SIZE);

    var timer = try std.time.Timer.start();
    const start = timer.lap();

    if (IS_MULTI_THREADED) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer if (gpa.deinit() == .leak) {
            @panic("PANIC: Memory leak has occurred!");
        };

        var arena = std.heap.ArenaAllocator.init(gpa.allocator());
        defer arena.deinit();
        var allocator = arena.allocator();

        var work_queue = std.atomic.Queue(Worker.Chunk).init();
        var done_count = std.atomic.Atomic(u32).init(0);

        var worker_idx: usize = 0;
        while (worker_idx < num_cores) : (worker_idx += 1) {
            workers.appendAssumeCapacity(.{ .done_count = &done_count, .queue = &work_queue });
            threads.appendAssumeCapacity(try std.Thread.spawn(.{}, Worker.spawn, .{ &workers.slice()[worker_idx], rng, FRAME_DIM }));
        }

        var chunk_idx: usize = 0;
        var thread_idx: usize = 0;
        while (chunk_idx < NUM_CHUNKS) : (chunk_idx += 1) {
            const node = try allocator.create(std.atomic.Queue(Worker.Chunk).Node);
            node.* = .{ .data = .{ .tracer = &tracer, .frame = frame.slice(), .offset = chunk_idx * CHUNK_SIZE, .size = CHUNK_SIZE } };
            workers.slice()[thread_idx].put(node);
            thread_idx = (thread_idx + 1) % num_cores;
        }

        Worker.waitUntilDone(&done_count, NUM_CHUNKS);

        for (threads.constSlice(), 0..) |thread, i| {
            Worker.join(thread, &workers.slice()[i]);
        }
    } else {
        Tracer.tracePaths(tracer, frame.slice(), 0, FRAME_DIM * FRAME_DIM, rng, FRAME_DIM);
    }

    try writer.print("Total duration: {}\n", .{std.fmt.fmtDuration(timer.read() - start)});
    try buf_writer.flush();

    try Tracer.renderPpm(frame.constSlice(), FRAME_DIM);
}
