const std = @import("std");
const zzmq = @import("zzmq");

pub fn main() !void {
    std.log.info("Starting the server...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak)
            @panic("Memory leaked");
    }

    const allocator = gpa.allocator();

    var socket = try zzmq.ZSocket.init(allocator, zzmq.ZSocketType.Rep);
    defer socket.deinit();

    _ = try socket.bind("tcp://127.0.0.1:5555");

    while (true) {
        // Wait for next request from client
        {
            var frame = try socket.receive();
            defer frame.deinit();

            const data = try frame.data();

            std.log.info("Received: {s}", .{data});
        }

        // Do some 'work'
        std.time.sleep(std.time.ns_per_s);

        // Send reply back to client
        {
            var frame = try zzmq.ZFrame.init("World");
            defer frame.deinit();

            try socket.send(&frame, .{});
        }
    }
}
