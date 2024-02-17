const std = @import("std");
const zframe = @import("zframe.zig");
const c = @import("../czmq.zig").c;

pub const ZSocketType = enum(c_int) {
    /// A socket of type ZMQ_PAIR can only be connected to a single peer at any one time.
    ///
    /// No message routing or filtering is performed on messages sent over a ZMQ_PAIR socket.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Pair = c.ZMQ_PAIR,

    /// A socket of type ZMQ_PUB is used by a publisher to distribute data.
    ///
    /// Messages sent are distributed in a fan out fashion to all connected peers.
    /// The zmq_recv function is not implemented for this socket type.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Pub = c.ZMQ_PUB,

    /// A socket of type ZMQ_SUB is used by a subscriber to subscribe to data distributed by a publisher.
    ///
    /// Initially a ZMQ_SUB socket is not subscribed to any messages, use the ZMQ_SUBSCRIBE option
    /// of zmq_setsockopt to specify which messages to subscribe to.
    /// The zmq_send() function is not implemented for this socket type.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Sub = c.ZMQ_SUB,

    /// Same as ZMQ_PUB except that you can receive subscriptions from the peers in form of incoming messages.
    ///
    /// Subscription message is a byte 1 (for subscriptions) or byte 0 (for unsubscriptions) followed by the subscription body.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    XPub = c.ZMQ_XPUB,

    /// Same as ZMQ_SUB except that you subscribe by sending subscription messages to the socket.
    ///
    /// Subscription message is a byte 1 (for subscriptions) or byte 0 (for unsubscriptions) followed by the subscription body.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    XSub = c.ZMQ_XSUB,

    /// A socket of type ZMQ_REQ is used by a client to send requests to and receive replies from a service.
    ///
    /// This socket type allows only an alternating sequence of zmq_send(request)
    /// and subsequent zmq_recv(reply) calls. Each request sent is round-robined among all services,
    /// and each reply received is matched with the last issued request.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Req = c.ZMQ_REQ,

    /// A socket of type ZMQ_REP is used by a service to receive requests from and send replies to a client.
    ///
    /// This socket type allows only an alternating sequence of zmq_recv(request) and subsequent zmq_send(reply) calls.
    /// Each request received is fair-queued from among all clients, and each reply sent is routed to the client that
    /// issued the last request. If the original requester doesn’t exist any more the reply is silently discarded.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Rep = c.ZMQ_REP,

    /// A socket of type ZMQ_DEALER is an advanced pattern used for extending request/reply sockets.
    ///
    /// Each message sent is round-robined among all connected peers, and each message received is fair-queued from all connected peers.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Dealer = c.ZMQ_DEALER,

    /// A socket of type ZMQ_ROUTER is an advanced socket type used for extending request/reply sockets.
    ///
    /// When receiving messages a ZMQ_ROUTER socket shall prepend a message part containing the identity
    /// of the originating peer to the message before passing it to the application.
    /// Messages received are fair-queued from among all connected peers.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Router = c.ZMQ_ROUTER,

    /// A socket of type ZMQ_PULL is used by a pipeline node to receive messages from upstream pipeline nodes.
    ///
    /// Messages are fair-queued from among all connected upstream nodes. The zmq_send() function is not implemented for this socket type.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Pull = c.ZMQ_PULL,

    /// A socket of type ZMQ_PUSH is used by a pipeline node to send messages to downstream pipeline nodes.
    ///
    /// Messages are round-robined to all connected downstream nodes.
    /// The zmq_recv() function is not implemented for this socket type.
    ///
    /// For more details, see https://libzmq.readthedocs.io/en/zeromq3-x/zmq_socket.html .
    Push = c.ZMQ_PUSH,
};

/// System level socket, which allows for opening outgoing and
/// accepting incoming connections.
pub const ZSocket = struct {
    allocator: std.mem.Allocator,
    selfArena: std.heap.ArenaAllocator,
    socket: *c.zsock_t,
    type: []const u8,
    endpoint: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, socketType: ZSocketType) !*ZSocket {
        // try creating the socket, early
        var s = c.zsock_new(@intFromEnum(socketType)) orelse return error.SocketCreateFailed;
        errdefer {
            var ss: ?*c.zsock_t = s;
            c.zsock_destroy(&ss);
        }

        // create the managed object
        var selfArena = std.heap.ArenaAllocator.init(allocator);
        errdefer selfArena.deinit();
        const selfAllocator = selfArena.allocator();

        var r = try selfAllocator.create(ZSocket);
        r.allocator = allocator;
        r.selfArena = selfArena;
        r.socket = s;
        r.endpoint = null;

        // get the socket type as string
        const typeStrZ = std.mem.span(c.zsock_type_str(s));

        r.type = try selfAllocator.dupe(u8, typeStrZ[0..typeStrZ.len]); // copy to managed memory

        // done
        return r;
    }

    ///  Bind a socket to a endpoint. For tcp:// endpoints, supports
    ///  ephemeral ports, if you specify the port number as "*". By default
    ///  zsock uses the IANA designated range from C000 (49152) to FFFF (65535).
    ///  To override this range, follow the "*" with "[first-last]". Either or
    ///  both first and last may be empty. To bind to a random port within the
    ///  range, use "!" in place of "*".
    ///
    ///  Examples:
    ///      tcp://127.0.0.1:*           bind to first free port from C000 up
    ///      tcp://127.0.0.1:!           bind to random port from C000 to FFFF
    ///      tcp://127.0.0.1:*[60000-]   bind to first free port from 60000 up
    ///      tcp://127.0.0.1:![-60000]   bind to random port from C000 to 60000
    ///      tcp://127.0.0.1:![55000-55999] bind to random port from 55000 to 55999
    ///
    ///  On success, returns the actual port number used, for tcp:// endpoints,
    ///  and 0 for other transports. Note that when using
    ///  ephemeral ports, a port may be reused by different services without
    ///  clients being aware. Protocols that run on ephemeral ports should take
    ///  this into account.
    pub fn bind(self: *ZSocket, ep: []const u8) !u16 {
        const epZ = try self.allocator.dupeZ(u8, ep);
        defer self.allocator.free(epZ);

        const result = c.zsock_bind(self.socket, "%s", &epZ[0]);

        if (result < 0) {
            return error.SocketBindFailed;
        }

        // retrieve endpoint value
        const selfAllocator = self.selfArena.allocator();

        if (self.endpoint) |e| {
            selfAllocator.free(e);
        }

        self.endpoint = try selfAllocator.dupe(u8, ep); // copy to managed memory

        // done
        return @intCast(result);
    }

    /// Connect a socket to an endpoint
    ///
    ///  Examples:
    ///      tcp://127.0.0.1:54321
    pub fn connect(self: *ZSocket, ep: []const u8) !void {
        const epZ = try self.allocator.dupeZ(u8, ep);
        defer self.allocator.free(epZ);

        const result = c.zsock_connect(self.socket, "%s", &epZ[0]);
        if (result < 0) {
            return error.SocketConnectFailed;
        }

        // retrieve endpoint value
        const selfAllocator = self.selfArena.allocator();

        if (self.endpoint) |e| {
            selfAllocator.free(e);
        }

        self.endpoint = try selfAllocator.dupe(u8, ep); // copy to managed memory
    }

    /// Send a frame to a socket.
    ///
    /// Example:
    ///       var frame = try ZFrame.init(data);
    ///       defer frame.deinit();
    ///
    ///       try socket.send(&frame, .{});
    pub fn send(self: *ZSocket, frame: *const zframe.ZFrame, options: struct {
        more: bool = false,
        dontwait: bool = false,
    }) !void {
        var f: ?*c.zframe_t = frame.frame;

        var flags: c_int = c.ZFRAME_REUSE;
        if (options.more) flags |= c.ZFRAME_MORE;
        if (options.dontwait) flags |= c.ZFRAME_DONTWAIT;

        const result = c.zframe_send(&f, self.socket, flags);
        if (result < 0) {
            return error.SendFrameFailed;
        }
    }

    /// Receive frame from socket, returns zframe_t object or NULL if the recv
    /// was interrupted. Does a blocking recv, if you want to not block then use
    /// zpoller or zloop.
    ///
    /// The caller must invoke `deinit()` on the returned frame.
    ///
    /// Example:
    ///       var frame = try socket.receive();
    ///       defer frame.deinit();
    ///
    ///       const data = frame.data();
    pub fn receive(self: *ZSocket) !zframe.ZFrame {
        var frame = c.zframe_recv(self.socket);
        if (frame == null) {
            return error.ReceiveFrameInterrupted;
        }

        return zframe.ZFrame{ .frame = frame.? };
    }

    /// Destroy the socket and clean up
    pub fn deinit(self: *ZSocket) void {
        var socket: ?*c.zsock_t = self.socket;

        c.zsock_destroy(&socket);

        // clean-up arena
        var arena = self.selfArena; // prevent seg fault
        arena.deinit();
    }
};

test "ZSocket - bind and connect" {
    const allocator = std.testing.allocator;

    // bind the incoming socket
    var incoming = try ZSocket.init(allocator, ZSocketType.Pair);
    defer incoming.deinit();

    const port = try incoming.bind("tcp://127.0.0.1:!");
    try std.testing.expect(port >= 0xC000);
    try std.testing.expect(incoming.endpoint != null);

    // connect to the socket
    var outgoing = try ZSocket.init(allocator, ZSocketType.Pair);
    defer outgoing.deinit();

    const endpoint = try std.fmt.allocPrint(allocator, "tcp://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    try outgoing.connect(endpoint);
    try std.testing.expect(outgoing.endpoint != null);

    // send a message
    const msg = "hello world";

    var outgoingData = try zframe.ZFrame.init(msg);
    defer outgoingData.deinit();
    try std.testing.expectEqual(msg.len, outgoingData.size());
    try std.testing.expectEqualStrings(msg, outgoingData.data());

    try outgoing.send(&outgoingData, .{ .dontwait = true });

    // receive the message
    var incomingData = try incoming.receive();
    defer incomingData.deinit();

    try std.testing.expectEqual(msg.len, incomingData.size());
    try std.testing.expectEqualStrings(msg, incomingData.data());
}
