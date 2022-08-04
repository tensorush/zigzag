const Builder = @import("std").build.Builder;

pub fn build(builder: *Builder) void {
    const mode = builder.standardReleaseOptions();
    const target = builder.standardTargetOptions(.{});

    const exe = builder.addExecutable("zigzag", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(builder.getInstallStep());

    const run_step = builder.step("run", "Zigzag through the scene!");
    run_step.dependOn(&run_cmd.step);
}
