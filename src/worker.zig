const std = @import("std");
const config = @import("config.zig");
const tracer = @import("tracer.zig");

pub const Worker = struct {
    done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    job_count: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
    done_count: *std.atomic.Atomic(u32),
    queue: *std.atomic.Queue(WorkChunk),
    cur_job_count: u32 = 0,

    pub fn launch(self: *Worker) (std.os.GetRandomError || error{TimedOut})!void {
        var work_item: WorkChunk = undefined;
        while (!self.done.load(.Acquire)) {
            if (!self.queue.isEmpty()) {
                work_item = self.queue.get().?.data;
                try tracer.tracePaths(work_item.tracer.*, work_item.buffer.*, work_item.offset, work_item.size);
                _ = self.done_count.fetchAdd(1, .Release);
                std.Thread.Futex.wake(self.done_count, 1);
            } else {
                try self.wait();
            }
        }
    }

    pub fn wait(self: *Worker) error{TimedOut}!void {
        var global_job_count: u32 = undefined;
        while (true) {
            global_job_count = self.job_count.load(.Acquire);
            if (global_job_count != self.cur_job_count) break;
            std.Thread.Futex.wait(&self.job_count, self.cur_job_count);
        }
    }

    pub fn put(self: *Worker, node: *std.atomic.Queue(WorkChunk).Node) void {
        self.queue.put(node);
        self.wake();
    }

    pub fn wake(self: *Worker) void {
        _ = self.job_count.fetchAdd(1, .Release);
        std.Thread.Futex.wake(&self.job_count, 1);
    }
};

pub const WorkChunk = struct {
    tracer: *tracer.Tracer,
    buffer: *[]u8,
    offset: usize,
    size: usize,
};

pub fn waitUntilDone(done_count: *std.atomic.Atomic(u32), target_count: u32) error{TimedOut}!void {
    var cur_done_count: u32 = undefined;
    while (config.IS_MULTI_THREADED) {
        cur_done_count = done_count.load(.Acquire);
        if (cur_done_count == target_count) break;
        std.Thread.Futex.wait(done_count, cur_done_count);
    }
}

pub fn joinThread(thread: std.Thread, worker: *Worker) void {
    worker.done.store(true, .Release);
    worker.wake();
    thread.join();
}
