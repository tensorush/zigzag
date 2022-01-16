const std = @import("std");
const config = @import("config.zig");
const tracer = @import("tracer.zig");

pub const WorkItem = struct {
    tracer: *tracer.Tracer,
    buffer: *[]u8,
    offset: usize,
    chunk_size: usize,
};

pub const WorkerThreadData = struct {
    queue: *std.atomic.Queue(WorkItem),
    job_counter: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
    cur_job_counter: u32 = 0,
    done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    done_count: *std.atomic.Atomic(u32),

    pub fn wait_for_job(self: *@This()) !void {
        var v: u32 = undefined;
        while (true) {
            v = self.job_counter.load(.Acquire);
            if (v != self.cur_job_counter) {
                break;
            }
            std.Thread.Futex.wait(&self.job_counter, self.cur_job_counter, null) catch unreachable;
        }
    }

    pub fn wake(self: *@This()) void {
        _ = self.job_counter.fetchAdd(1, .Release);
        std.Thread.Futex.wake(&self.job_counter, 1);
    }

    pub fn push_job_and_wake(self: *@This(), node: *std.atomic.Queue(WorkItem).Node) void {
        self.queue.put(node);
        self.wake();
    }
};

pub fn worker_thread(worker_data: *WorkerThreadData) !void {
    var work_item: WorkItem = undefined;
    while (!worker_data.done.load(.Acquire)) {
        if (!worker_data.queue.isEmpty()) {
            work_item = worker_data.queue.get().?.data;
            try tracer.trace_paths(work_item.tracer.*, work_item.buffer.*, work_item.offset, work_item.chunk_size);
            _ = worker_data.done_count.fetchAdd(1, .Release);
            std.Thread.Futex.wake(worker_data.done_count, 1);
        } else {
            try worker_data.wait_for_job();
        }
    }
}

pub fn join_thread(t: std.Thread, data: *WorkerThreadData) void {
    data.done.store(true, .Release);
    data.wake();
    t.join();
}

pub fn wait_until_done(c: *std.atomic.Atomic(u32), goal_c: u32) !void {
    while (config.IS_MULTI_THREADED) {
        const cv = c.load(.Acquire);
        if (cv == goal_c) {
            break;
        }
        std.Thread.Futex.wait(c, cv, null) catch unreachable;
    }
}
