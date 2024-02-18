const std = @import("std");
const zzmq = @import("zzmq");

fn senderThreadMain(socket: *zzmq.ZSocket, stop: *bool, allocator: std.mem.Allocator) !void {
    var index: usize = 0;

    while (!stop.*) {
        index += 1;

        std.log.info("Sending {}...", .{index});

        // Send the header (empty)
        // See https://zguide.zeromq.org/docs/chapter3/#The-DEALER-to-REP-Combination
        {
            var frame = try zzmq.ZFrame.initEmpty();
            defer frame.deinit();

            while (!stop.*) { // retry until a client connects
                socket.send(&frame, .{ .more = true }) catch continue;
                break;
            }
            if (stop.*) return;
        }

        // Send the request
        {
            var body = try std.fmt.allocPrint(allocator, "Hello: {}", .{index});
            defer allocator.free(body);

            var frame = try zzmq.ZFrame.init(body);
            defer frame.deinit();

            try socket.send(&frame, .{});
        }

        // wait a moment
        std.time.sleep(50 * std.time.ns_per_ms);
    }
}

var senderThreadStop = false;

fn sig_handler(sig: c_int) align(1) callconv(.C) void {
    _ = sig;
    senderThreadStop = true;
}

const sig_ign = std.os.Sigaction{
    .handler = .{ .handler = &sig_handler },
    .mask = std.os.empty_sigset,
    .flags = 0,
};

pub fn main() !void {
    try std.os.sigaction(std.os.SIG.INT, &sig_ign, null);
    try std.os.sigaction(std.os.SIG.TERM, &sig_ign, null);

    std.log.info("Starting the server...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak)
            @panic("Memory leaked");
    }

    const allocator = gpa.allocator();

    var socket = try zzmq.ZSocket.init(allocator, zzmq.ZSocketType.Dealer);
    defer socket.deinit();

    try socket.setSocketOption(.{ .ReceiveTimeout = 500 });
    try socket.setSocketOption(.{ .SendTimeout = 500 });
    try socket.setSocketOption(.{ .SendHighWaterMark = 50 });
    try socket.setSocketOption(.{ .SendBufferSize = 256 }); // keep it small

    _ = try socket.bind("tcp://127.0.0.1:5555");

    // start sending threads
    const senderThread = try std.Thread.spawn(.{}, senderThreadMain, .{ socket, &senderThreadStop, allocator });
    defer {
        senderThreadStop = true;
        senderThread.join();
    }

    while (!senderThreadStop) {
        // Wait for the next reply
        {
            var frame = socket.receive() catch continue;
            defer frame.deinit();

            if (@as(usize, 0) != try frame.size() or !try frame.hasMore()) { // ignore anything that is not a delimiter frame
                continue;
            }
        }

        // read the content frames
        while (true) {
            var frame = try socket.receive();
            defer frame.deinit();

            const data = try frame.data();

            std.log.info("Received: {s}", .{data});

            if (!try frame.hasMore()) break;
        }
    }
}
