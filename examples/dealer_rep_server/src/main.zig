const std = @import("std");
const zzmq = @import("zzmq");

var stopRunning_ = std.atomic.Atomic(bool).init(false);
const stopRunning = &stopRunning_;

fn senderThreadMain(socket: *zzmq.ZSocket, allocator: std.mem.Allocator) !void {
    var index: usize = 0;

    while (!stopRunning.load(.SeqCst)) {
        index += 1;

        std.log.info("Sending {}...", .{index});

        // Send the header (empty)
        // See https://zguide.zeromq.org/docs/chapter3/#The-DEALER-to-REP-Combination
        {
            while (!stopRunning.load(.SeqCst)) { // retry until a client connects
                var msg = try zzmq.ZMessage.initExternalEmpty();
                defer msg.deinit();

                socket.send(&msg, .{ .more = true }) catch |err| {
                    std.log.info("Waiting for first client to connect: {}", .{err});

                    std.time.sleep(1 * std.time.ns_per_s);
                    continue;
                };

                break; // success, exit retry loop
            }
            if (stopRunning.load(.SeqCst)) return;
        }

        // Send the request
        {
            var body = try std.fmt.allocPrint(allocator, "Hello: {}", .{index});
            defer allocator.free(body);

            var msg = try zzmq.ZMessage.init(allocator, body);
            defer msg.deinit();

            try socket.send(&msg, .{});
        }

        // wait a moment
        std.time.sleep(50 * std.time.ns_per_ms);
    }
}

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

    var socket = try zzmq.ZSocket.init(zzmq.ZSocketType.Dealer, &context);
    defer socket.deinit();

    try socket.setSocketOption(.{ .ReceiveTimeout = 500 });
    try socket.setSocketOption(.{ .SendTimeout = 500 });
    try socket.setSocketOption(.{ .SendHighWaterMark = 50 });
    try socket.setSocketOption(.{ .SendBufferSize = 256 }); // keep it small

    try std.os.sigaction(std.os.SIG.INT, &sig_ign, null);
    try std.os.sigaction(std.os.SIG.TERM, &sig_ign, null);

    try socket.bind("tcp://127.0.0.1:5555");

    // start sending threads
    const senderThread = try std.Thread.spawn(.{}, senderThreadMain, .{ socket, allocator });
    defer {
        stopRunning.store(true, .SeqCst);
        senderThread.join();
    }

    while (!stopRunning.load(.SeqCst)) {
        // Wait for the next reply
        {
            var msg = socket.receive(.{}) catch continue;
            defer msg.deinit();

            if (@as(usize, 0) != try msg.size() or !msg.hasMore()) { // ignore anything that is not a delimiter frame
                continue;
            }
        }

        // read the content frames
        while (true) {
            var msg = try socket.receive(.{});
            defer msg.deinit();

            const data = try msg.data();

            std.log.info("Received: {s}", .{data});

            if (!msg.hasMore()) break;
        }
    }
}
