const std = @import("std");
const Tracer = @import("Tracer.zig");

const Worker = @This();

is_done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
job_count: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
done_count: *std.atomic.Atomic(u32),
queue: *std.atomic.Queue(Chunk),
cur_job_count: u32 = 0,

pub const Chunk = struct {
    tracer: *Tracer,
    frame: []u8,
    offset: u16,
    size: u16,
};

pub fn spawn(self: *Worker, rng: std.rand.Random, render_dim: u16) void {
    while (!self.is_done.load(.Acquire)) {
        if (self.queue.get()) |chunk| {
            chunk.data.tracer.tracePaths(chunk.data.frame, chunk.data.offset, chunk.data.size, rng, render_dim);
            _ = self.done_count.fetchAdd(1, .Release);
            std.Thread.Futex.wake(self.done_count, 1);
        } else {
            self.wait();
        }
    }
}

pub fn put(self: *Worker, node: *std.atomic.Queue(Chunk).Node) void {
    self.queue.put(node);
    self.wake();
}

pub fn wake(self: *Worker) void {
    _ = self.job_count.fetchAdd(1, .Release);
    std.Thread.Futex.wake(&self.job_count, 1);
}

pub fn join(thread: std.Thread, worker: *Worker) void {
    worker.is_done.store(true, .Release);
    worker.wake();
    thread.join();
}

pub fn wait(self: *Worker) void {
    while (true) {
        const job_count = self.job_count.load(.Acquire);
        if (job_count != self.cur_job_count) {
            break;
        }
        std.Thread.Futex.wait(&self.job_count, self.cur_job_count);
    }
}

pub fn waitUntilDone(done_count: *std.atomic.Atomic(u32), target_count: u32) void {
    while (true) {
        const cur_done_count = done_count.load(.Acquire);
        if (cur_done_count == target_count) {
            break;
        }
        std.Thread.Futex.wait(done_count, cur_done_count);
    }
}
