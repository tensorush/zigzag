const std = @import("std");
const clap = @import("clap");
const Scene = @import("Scene.zig");
const Tracer = @import("Tracer.zig");
const vector = @import("vector.zig");

const MAX_NUM_COLOR_PIXELS: u32 = 1 << 22;

const PARAMS = clap.parseParamsComptime(
    \\-r, --render <u16>  Square render dimension.
    \\-c, --chunk <u16>   Worker chunk size.
    \\-h, --help          Help menu.
    \\<str>               Render file path.
    \\
);

const log = std.log.scoped(.zigzag);

const Error = error{
    UnexpectedRemainder,
    DivisionByZero,
    Overflow,
} || std.os.GetRandomError || std.Thread.CpuCountError || std.Thread.SpawnError || std.fs.File.OpenError || std.os.WriteError || std.time.Timer.Error;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("PANIC: Memory leak has occurred!");
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &PARAMS, clap.parsers.default, .{ .diagnostic = &diag }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    var render_file_path: []const u8 = "renders/render.ppm";
    var render_dim: u16 = 1 << 10;
    var chunk_size: u16 = 1 << 8;

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

    const render_size = @as(u32, render_dim) * @as(u32, render_dim);
    const num_chunks = try std.math.divExact(u32, render_size, chunk_size);
    const num_color_pixels = render_size * vector.LEN;

    var tracer = Tracer{ .scene = Scene.initCornellBox() };

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = prng.random();

    Tracer.samplePixels(&tracer.samples, rng);

    var color_pixels = std.BoundedArray(u8, MAX_NUM_COLOR_PIXELS){};
    color_pixels.appendNTimesAssumeCapacity(0, num_color_pixels);

    var timer = try std.time.Timer.start();
    const start = timer.lap();

    {
        var thread_pool: std.Thread.Pool = undefined;
        try thread_pool.init(.{ .allocator = allocator });
        defer thread_pool.deinit();

        var wait_group = std.Thread.WaitGroup{};
        defer wait_group.wait();

        var chunk_idx: u32 = 0;
        while (chunk_idx < num_chunks) : (chunk_idx += 1) {
            wait_group.start();

            try thread_pool.spawn(Tracer.tracePaths, .{ tracer, &wait_group, color_pixels.slice(), chunk_idx * chunk_size, chunk_size, rng, render_dim });
        }
    }

    log.info("Total duration: {}", .{std.fmt.fmtDuration(timer.read() - start)});

    try Tracer.renderPpm(color_pixels.constSlice(), render_dim, render_file_path);
}
