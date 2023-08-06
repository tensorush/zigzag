const std = @import("std");
const clap = @import("clap");
const Scene = @import("Scene.zig");
const Tracer = @import("Tracer.zig");
const vector = @import("vector.zig");
const Worker = @import("Worker.zig");

const IS_MULTI_THREADED = true;
const MAX_NUM_CORES: u8 = 1 << 4;
const MAX_RENDER_SIZE: u32 = 1 << 22;

const PARAMS = clap.parseParamsComptime(
    \\-r, --render <u16>  Square render dimension.
    \\-c, --chunk <u16>   Worker chunk size.
    \\-h, --help          Help menu.
    \\<str>               Render file path.
    \\
);

const log = std.log.scoped(.zigzag);

const MainError = std.os.GetRandomError || std.Thread.CpuCountError || std.Thread.SpawnError || std.fs.File.OpenError || std.os.WriteError || std.time.Timer.Error;

pub fn main() anyerror!void {
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &PARAMS, clap.parsers.default, .{ .diagnostic = &diag }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    var render_file_path: []const u8 = "renders/render.ppm";
    var chunk_size: u16 = 1 << 8;
    var render_dim: u16 = 1 << 10;

    if (res.args.chunk) |chunk| {
        chunk_size = chunk;
    }

    if (res.args.render) |render| {
        render_dim = render;
    }

    for (res.positionals) |pos| {
        render_file_path = pos;
    }

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &PARAMS, .{});
    }

    const render_size = @as(u32, render_dim) * @as(u32, render_dim) * @as(u32, vector.LEN);
    const num_chunks = @as(u32, render_dim) * @as(u32, render_dim) / @as(u32, chunk_size);

    var tracer = Tracer{ .scene = Scene.initCornellBox() };

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = prng.random();

    Tracer.samplePixels(&tracer.samples, rng);

    const num_cores: u8 = @intCast(try std.Thread.getCpuCount());
    log.info("Number of CPU cores: {d}", .{num_cores});

    var threads = std.BoundedArray(std.Thread, MAX_NUM_CORES){};
    var workers = std.BoundedArray(Worker, MAX_NUM_CORES){};
    var render = std.BoundedArray(u8, MAX_RENDER_SIZE){};
    render.appendNTimesAssumeCapacity(0, render_size);

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

        var worker_idx: u8 = 0;
        while (worker_idx < num_cores) : (worker_idx += 1) {
            workers.appendAssumeCapacity(.{ .done_count = &done_count, .queue = &work_queue });
            threads.appendAssumeCapacity(try std.Thread.spawn(.{}, Worker.spawn, .{ &workers.slice()[worker_idx], rng, render_dim }));
        }

        var chunk_idx: u32 = 0;
        var thread_idx: u8 = 0;
        while (chunk_idx < num_chunks) : (chunk_idx += 1) {
            const node = try allocator.create(std.atomic.Queue(Worker.Chunk).Node);
            node.* = .{ .data = .{ .tracer = &tracer, .render = render.slice(), .offset = chunk_idx * chunk_size, .size = chunk_size } };
            workers.slice()[thread_idx].put(node);
            thread_idx = (thread_idx + 1) % num_cores;
        }

        Worker.waitUntilDone(&done_count, num_chunks);

        for (threads.constSlice(), 0..) |thread, i| {
            Worker.join(thread, &workers.slice()[i]);
        }
    } else {
        Tracer.tracePaths(tracer, render.slice(), 0, render_dim * render_dim, rng, render_dim);
    }

    log.info("Total duration: {}", .{std.fmt.fmtDuration(timer.read() - start)});

    try Tracer.renderPpm(render.constSlice(), render_dim, render_file_path);
}
