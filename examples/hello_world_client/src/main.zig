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

    var socket = try zzmq.ZSocket.init(allocator, zzmq.ZSocketType.Req);
    defer socket.deinit();

    try socket.connect("tcp://127.0.0.1:5555");

    // Do 10 requests, waiting each time for a response
    for (0..9) |i| {
        // Send the request
        {
            std.log.info("Sending request {}...", .{i});

            var frame = try zzmq.ZFrame.init("Hello");
            defer frame.deinit();

            try socket.send(&frame, .{});
        }

        // Receive the reply
        {
            var frame = try socket.receive();
            defer frame.deinit();

            const data = try frame.data();

            std.log.info("Received reply {} [ {s} ]", .{ i, data });
        }
    }
}
