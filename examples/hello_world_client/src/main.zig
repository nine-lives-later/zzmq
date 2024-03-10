const std = @import("std");
const zzmq = @import("zzmq");

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

    var socket = try zzmq.ZSocket.init(zzmq.ZSocketType.Req, &context);
    defer socket.deinit();

    try socket.connect("tcp://127.0.0.1:5555");

    // Do 10 requests, waiting each time for a response
    for (0..9) |i| {
        // Send the request
        {
            std.log.info("Sending request {}...", .{i});

            var msg = try zzmq.ZMessage.initUnmanaged("Hello", null);
            defer msg.deinit();

            try socket.send(&msg, .{});
        }

        // Receive the reply
        {
            var msg = try socket.receive(.{});
            defer msg.deinit();

            const data = try msg.data();

            std.log.info("Received reply {} [ {s} ]", .{ i, data });
        }
    }
}
