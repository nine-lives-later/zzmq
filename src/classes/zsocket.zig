const std = @import("std");

const c = @cImport({
    @cInclude("czmq.h");
    @cInclude("string.h");
});

pub const ZSocketType = enum(c_int) {
    Pair = c.ZMQ_PAIR,
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
}
