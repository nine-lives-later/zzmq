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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak)
            @panic("Memory leaked");
    }

    const allocator = gpa.allocator();

    var socket = try zzmq.ZSocket.init(allocator, zzmq.ZSocketType.Rep);
    defer socket.deinit();

    try socket.setSocketOption(.{ .ReceiveTimeout = 5000 });
    try socket.setSocketOption(.{ .ReceiveHighWaterMark = 2 }); // only 1 per thread + 1 reserve
    try socket.setSocketOption(.{ .ReceiveBufferSize = 256 }); // keep it small
    try socket.setSocketOption(.{ .SendTimeout = 500 });

    try std.os.sigaction(std.os.SIG.INT, &sig_ign, null); // ZSocket.init() will re-assign interrupts
    try std.os.sigaction(std.os.SIG.TERM, &sig_ign, null);

    try socket.connect("tcp://127.0.0.1:5555");

    while (!stopRunning.load(.SeqCst)) {
        // Receive the request
        {
            var frame = try socket.receive();
            defer frame.deinit();

            const data = try frame.data();

            std.log.info("Received request: {s}", .{data});
        }

        // wait a moment
        std.time.sleep(200 * std.time.ns_per_ms);

        // Send the reply
        {
            std.log.info("Sending reply...", .{});

            var frame = try zzmq.ZFrame.init("World");
            defer frame.deinit();

            try socket.send(&frame, .{});
        }
    }
}
