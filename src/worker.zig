const std = @import("std");
const Config = @import("Config.zig");
const tracer = @import("tracer.zig");

pub const WorkChunk = struct {
    tracer: *tracer.Tracer,
    buffer: *[]u8,
    offset: usize,
    size: usize,
};

pub const Worker = struct {
    done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    job_count: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
    done_count: *std.atomic.Atomic(u32),
    queue: *std.atomic.Queue(WorkChunk),
    cur_job_count: u32 = 0,

    pub fn wake(self: *Worker) void {
        _ = self.job_count.fetchAdd(1, .Release);
        std.Thread.Futex.wake(&self.job_count, 1);
    }

    pub fn put(self: *Worker, node: *std.atomic.Queue(WorkChunk).Node) void {
        self.queue.put(node);
        self.wake();
    }

    pub fn wait(self: *Worker) !void {
        var global_job_count: u32 = undefined;
        while (true) {
            global_job_count = self.job_count.load(.Acquire);
            if (global_job_count != self.cur_job_count) {
                break;
            }
            std.Thread.Futex.wait(&self.job_count, self.cur_job_count, null) catch unreachable;
        }
    }

    pub fn launch(self: *Worker) !void {
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
};

pub fn joinThread(thread: std.Thread, worker: *Worker) void {
    worker.done.store(true, .Release);
    worker.wake();
    thread.join();
}

pub fn waitUntilDone(done_count: *std.atomic.Atomic(u32), target_count: u32) !void {
    var cur_done_count: u32 = undefined;
    while (Config.IS_MULTI_THREADED) {
        cur_done_count = done_count.load(.Acquire);
        if (cur_done_count == target_count) {
            break;
        }
        std.Thread.Futex.wait(done_count, cur_done_count, null) catch unreachable;
    }
}
