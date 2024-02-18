const std = @import("std");
const zzmq = @import("zzmq");

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

    try socket.connect("tcp://127.0.0.1:5555");

    while (true) {
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
