const std = @import("std");
const zzmq = @import("zzmq");

var stopRunning_ = std.atomic.Atomic(bool).init(false);
const stopRunning = &stopRunning_;

fn sig_handler(sig: c_int) align(1) callconv(.C) void {
    _ = sig;
    std.log.info("Stopping...", .{});

    stopRunning.store(true, .SeqCst);
}

const sig_ign = std.os.Sigaction{
    .handler = .{ .handler = &sig_handler },
    .mask = std.os.empty_sigset,
    .flags = 0,
};

pub fn main() !void {
    std.log.info("Connecting to the server...", .{});

    {
        const version = zzmq.ZContext.version();

        std.log.info("libzmq version: {}.{}.{}", .{ version.major, version.minor, version.patch });
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak)
            @panic("Memory leaked");
    }

    const allocator = gpa.allocator();

    var context = try zzmq.ZContext.init(allocator);
    defer context.deinit();

    var socket = try zzmq.ZSocket.init(zzmq.ZSocketType.Rep, &context);
    defer socket.deinit();

    try socket.setSocketOption(.{ .ReceiveTimeout = 5000 });
    try socket.setSocketOption(.{ .ReceiveHighWaterMark = 2 }); // only 1 per thread + 1 reserve
    try socket.setSocketOption(.{ .ReceiveBufferSize = 256 }); // keep it small
    try socket.setSocketOption(.{ .SendTimeout = 500 });

    try std.os.sigaction(std.os.SIG.INT, &sig_ign, null);
    try std.os.sigaction(std.os.SIG.TERM, &sig_ign, null);

    try socket.connect("tcp://127.0.0.1:5555");

    while (!stopRunning.load(.SeqCst)) {
        // Receive the request
        {
            var msg = try socket.receive(.{});
            defer msg.deinit();

            const data = try msg.data();

            std.log.info("Received request: {s}", .{data});
        }

        // wait a moment
        std.time.sleep(200 * std.time.ns_per_ms);

        // Send the reply
        {
            std.log.info("Sending reply...", .{});

            var msg = try zzmq.ZMessage.initUnmanaged("World", null);
            defer msg.deinit();

            try socket.send(&msg, .{});
        }
    }
}
