const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zzmq", .{
        .root_source_file = b.path("src/zzmq.zig"),
    });

    const lib_test = b.addTest(.{
        .root_source_file = b.path("src/zzmq.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_test.linkSystemLibrary("zmq");
    lib_test.linkLibC();

    const run_test = b.addRunArtifact(lib_test);
    run_test.has_side_effects = true;

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
