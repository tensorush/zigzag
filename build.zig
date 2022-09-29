const Builder = @import("std").build.Builder;

pub fn build(builder: *Builder) void {
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    const exe = builder.addExecutable("Zigzag", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(builder.getInstallStep());

    const run_step = builder.step("run", "Zigzag through the scene!");
    run_step.dependOn(&run_cmd.step);
}
