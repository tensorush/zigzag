const std = @import("std");

pub fn build(b: *std.Build) void {
    const root_source_file = std.Build.FileSource.relative("src/main.zig");

    // Dependencies
    const clap_dep = b.dependency("clap", .{});
    const clap_mod = clap_dep.module("clap");

    // Executable
    const exe_step = b.step("exe", "Run Zigzag path tracer");

    const exe = b.addExecutable(.{
        .name = "zigzag",
        .root_source_file = root_source_file,
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .version = .{ .major = 1, .minor = 4, .patch = 0 },
    });
    exe.addModule("clap", clap_mod);
    b.installArtifact(exe);

    const exe_run = b.addRunArtifact(exe);
    if (b.args) |args| {
        exe_run.addArgs(args);
    }

    exe_step.dependOn(&exe_run.step);
    b.default_step.dependOn(exe_step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}
