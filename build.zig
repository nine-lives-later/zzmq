const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_zmq = b.addModule("zzmq", .{
        .root_source_file = b.path("src/zzmq.zig"),
    });

    const prefix = b.option([]const u8, "prefix", "zmq installed path");
    
    if (prefix) |p| {
        mod_zmq.addIncludePath(.{ .cwd_relative = b.pathResolve(&[_][]const u8 { p, "zmq/include" }) } );
    }

    const lib_test = b.addTest(.{
        .root_source_file = b.path("src/zzmq.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (prefix) |p| {
        lib_test.addIncludePath(.{ .cwd_relative = b.pathResolve(&[_][]const u8 { p, "zmq/include" }) } );
        lib_test.addLibraryPath(.{ .cwd_relative = b.pathResolve(&[_][]const u8 { p, "zmq/lib" }) });
    }

    lib_test.linkSystemLibrary("zmq");
    lib_test.linkLibC();

    const run_test = b.addRunArtifact(lib_test);
    run_test.has_side_effects = true;

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
