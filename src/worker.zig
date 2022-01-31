const std = @import("std");
const config = @import("config.zig");
const tracer = @import("tracer.zig");

pub const WorkItem = struct {
    tracer: *tracer.Tracer,
    buffer: *[]u8,
    offset: usize,
    chunk_size: usize,
};

pub const WorkerThread = struct {
    done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    done_count: *std.atomic.Atomic(u32),
    job_count: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
    cur_job_count: u32 = 0,
    queue: *std.atomic.Queue(WorkItem),

    pub fn wake(self: *@This()) void {
        _ = self.job_count.fetchAdd(1, .Release);
        std.Thread.Futex.wake(&self.job_count, 1);
    }

    pub fn pushJobAndWake(self: *@This(), node: *std.atomic.Queue(WorkItem).Node) void {
        self.queue.put(node);
        self.wake();
    }

    pub fn waitForJob(self: *@This()) !void {
        var global_job_count: u32 = undefined;
        while (true) {
            global_job_count = self.job_count.load(.Acquire);
            if (global_job_count != self.cur_job_count) {
                break;
            }
            std.Thread.Futex.wait(&self.job_count, self.cur_job_count, null) catch unreachable;
        }
    }
};

pub fn joinThread(thread: std.Thread, data: *WorkerThread) void {
    data.done.store(true, .Release);
    data.wake();
    thread.join();
}

pub fn launchWorkerThread(worker_data: *WorkerThread) !void {
    var work_item: WorkItem = undefined;
    while (!worker_data.done.load(.Acquire)) {
        if (!worker_data.queue.isEmpty()) {
            work_item = worker_data.queue.get().?.data;
            try tracer.tracePaths(work_item.tracer.*, work_item.buffer.*, work_item.offset, work_item.chunk_size);
            _ = worker_data.done_count.fetchAdd(1, .Release);
            std.Thread.Futex.wake(worker_data.done_count, 1);
        } else {
            try worker_data.waitForJob();
        }
    }
}

pub fn waitUntilDone(done_count: *std.atomic.Atomic(u32), target_count: u32) !void {
    var cur_done_count: u32 = undefined;
    while (config.IS_MULTI_THREADED) {
        cur_done_count = done_count.load(.Acquire);
        if (cur_done_count == target_count) {
            break;
        }
        std.Thread.Futex.wait(done_count, cur_done_count, null) catch unreachable;
    }
}
