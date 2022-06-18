const Builder = @import("std").build.Builder;

pub fn build(builder: *Builder) void {
    const mode = builder.standardReleaseOptions();
    const target = builder.standardTargetOptions(.{});

    const exe = builder.addExecutable("zigzag-path-tracer", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(builder.getInstallStep());
    if (builder.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = builder.step("run", "Zigzag through the scene!");
    run_step.dependOn(&run_cmd.step);
}
