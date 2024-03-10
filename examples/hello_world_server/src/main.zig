const std = @import("std");
const zzmq = @import("zzmq");

pub fn main() !void {
    std.log.info("Starting the server...", .{});

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

    try socket.bind("tcp://127.0.0.1:5555");

    while (true) {
        // Wait for next request from client
        {
            var frame = try socket.receive(.{});
            defer frame.deinit();

            const data = try frame.data();

            std.log.info("Received: {s}", .{data});
        }

        // Do some 'work'
        std.time.sleep(std.time.ns_per_s);

        // Send reply back to client
        {
            var msg = try zzmq.ZMessage.initUnmanaged("World", null);
            defer msg.deinit();

            try socket.send(&msg, .{});
        }
    }
}
