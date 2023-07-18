const std = @import("std");

pub fn build(b: *std.Build) void {
    const root_source_file = std.Build.FileSource.relative("src/main.zig");

    // Zigzag path tracer
    const zigzag_step = b.step("zigzag", "Run Zigzag path tracer");

    const zigzag = b.addExecutable(.{
        .name = "zigzag",
        .root_source_file = root_source_file,
        .target = b.standardTargetOptions(.{}),
        .optimize = .ReleaseFast,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });
    b.installArtifact(zigzag);

    const zigzag_run = b.addRunArtifact(zigzag);
    zigzag_step.dependOn(&zigzag_run.step);
    b.default_step.dependOn(zigzag_step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &[_][]const u8{ "src", "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}
