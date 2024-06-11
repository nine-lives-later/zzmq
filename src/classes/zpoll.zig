const std = @import("std");
const zcontext = @import("zcontext.zig");
const zmessage = @import("zmessage.zig");
const zsocket = @import("zsocket.zig");
const c = @import("../zmq.zig").c;

pub const ZPollEvent = enum(i16) {
    PollIn = 1,
    PollOut = 2,
    PollErr = 4,
    PollPri = 8,
};

pub const ZPollItem = struct {
    /// The ZSocket that the event will poll on
    socket: *zsocket.ZSocket,

    /// File descriptor associated with the socket
    fd: i32 = 0,

    /// Bitmask specifying the events to poll for on the socket.
    events: i16 = 0,

    /// Bitmask specifying the events that occurred on the socket during polling
    revents: i16 = 0,

    /// Produces a ZPollItem. At compile time events are merged to a single bitmask flag.
    pub fn build(socket: *zsocket.ZSocket, fd: i32, comptime events: []const ZPollEvent) ZPollItem {
        comptime var flag: i16 = 0;
        inline for (events) |eventFlag| {
            flag |= @intFromEnum(eventFlag);
        }
        return .{
            .socket = socket,
            .fd = fd,
            .events = flag,
            .revents = 0,
        };
    }
};

/// The size indicates the number of poll items that the ZPoll can contain.
pub fn ZPoll(size: usize) type {
    return struct {
        const Self = @This();
        pollItems_: [size]c.zmq_pollitem_t = undefined,

        /// Sets up a new ZPoll instance
        pub fn init(poll_items: []const ZPollItem) Self {
            var zpoll = Self{};
            for (0.., poll_items) |i, item| {
                zpoll.pollItems_[i] = .{
                    .socket = item.socket.socket_,
                    .fd = item.fd,
                    .events = item.events,
                    .revents = item.revents,
                };
            }
            return zpoll;
        }

        /// Gets the returned events bitmask
        pub fn returnedEvents(self: *Self, index: usize) i16 {
            return self.pollItems_[index].revents;
        }

        /// Verifies if all requested events are flagged at the given index in the returned events.
        /// At compile time events are merged to a single bitmask flag.
        pub fn eventsOccurred(self: *Self, index: usize, comptime events: []const ZPollEvent) bool {
            comptime var flag = 0;
            inline for (events) |eventFlag| {
                flag |= @intFromEnum(eventFlag);
            }
            return self.pollItems_[index].revents & flag != 0;
        }

        /// Perform polling on multiple ZeroMQ sockets to check for events.
        /// Equivalent to the zmq_poll function.
        pub fn poll(self: *Self, len: usize, timeout: i64) !void {
            const rc = c.zmq_poll(&self.pollItems_, @intCast(len), timeout);
            if (rc < 0) {
                return switch (c.zmq_errno()) {
                    c.ETERM => error.ZSocketTerminated,
                    c.EFAULT => error.ItemsInvalid,
                    c.EINTR => error.Interrupted,
                    else => return error.PollFailed,
                };
            }
        }
    };
}

test "ZPoll - two sockets" {
    const allocator = std.testing.allocator;

    var context = try zcontext.ZContext.init(allocator);
    defer context.deinit();

    const router1 = try zsocket.ZSocket.init(.Router, &context);
    defer router1.deinit();
    try router1.bind("inproc://test-socket1");

    const router2 = try zsocket.ZSocket.init(.Router, &context);
    defer router2.deinit();
    try router2.bind("inproc://test-socket2");

    var msg = try zmessage.ZMessage.initUnmanaged("testmsg", null);
    defer msg.deinit();

    const req1 = try zsocket.ZSocket.init(.Req, &context);
    defer req1.deinit();
    try req1.connect("inproc://test-socket1");
    try req1.send(&msg, .{});

    const req2 = try zsocket.ZSocket.init(.Req, &context);
    defer req2.deinit();
    try req2.connect("inproc://test-socket2");
    try req2.send(&msg, .{});

    var poll = ZPoll(2).init(&[_]ZPollItem{
        ZPollItem.build(router1, 0, &[_]ZPollEvent{.PollIn}),
        ZPollItem.build(router2, 0, &[_]ZPollEvent{.PollIn}),
    });

    try poll.poll(1, 1000);
    try std.testing.expect(poll.eventsOccurred(0, &[_]ZPollEvent{.PollIn}));
    try poll.poll(2, 1000);
    try std.testing.expect(poll.eventsOccurred(1, &[_]ZPollEvent{.PollIn}));
}
