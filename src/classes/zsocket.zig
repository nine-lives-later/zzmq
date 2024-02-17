const std = @import("std");

const c = @cImport({
    @cInclude("czmq.h");
});

pub const ZSocketType = enum(c_int) {
    Pair = c.ZMQ_PAIR,
};

pub const ZSocket = struct {
allocator: std.mem.Allocator,
    socket: *c.zsock_t,

    pub fn init(allocator: std.mem.Allocator, socketType: ZSocketType) !ZSocket {
        var s = c.zsock_new(@intFromEnum(socketType)) orelse return error.SocketCreateFailed;
        errdefer c.zsock_destroy(&s);

        return ZSocket{
        .allocator = allocator,
            .socket = s,
        };
    }

//  Bind a socket to a formatted endpoint. For tcp:// endpoints, supports
//  ephemeral ports, if you specify the port number as "*". By default
//  zsock uses the IANA designated range from C000 (49152) to FFFF (65535).
//  To override this range, follow the "*" with "[first-last]". Either or
//  both first and last may be empty. To bind to a random port within the
//  range, use "!" in place of "*".
//
//  Examples:
//      tcp://127.0.0.1:*           bind to first free port from C000 up
//      tcp://127.0.0.1:!           bind to random port from C000 to FFFF
//      tcp://127.0.0.1:*[60000-]   bind to first free port from 60000 up
//      tcp://127.0.0.1:![-60000]   bind to random port from C000 to 60000
//      tcp://127.0.0.1:![55000-55999]
//                                  bind to random port from 55000 to 55999
//
//  On success, returns the actual port number used, for tcp:// endpoints,
//  and 0 for other transports. Note that when using
//  ephemeral ports, a port may be reused by different services without
//  clients being aware. Protocols that run on ephemeral ports should take
//  this into account.
pub fn bind(self: *ZSocket, endpoint: []const u8) !u16 {
    const endpointZ = try self.allocator.dupeZ(u8, endpoint);
    defer self.allocator.free(endpointZ);

    // TODO: better: `c.zsock_bind(self.socket, "%s", endpointZ)` for safety
    const result = c.zsock_bind(self.socket, endpointZ);
    if (result < 0) {
        return error.SocketBindFailed;
    }

    return @intCast(result);
}

    pub fn deinit(self: *ZSocket) void {
        var socket: ?*c.zsock_t = self.socket;

        c.zsock_destroy(&socket);
    }
};

test "ZSocket - bind and connect" {
    const allocator = std.testing.allocator;

    var s = try ZSocket.init(allocator, ZSocketType.Pair);
    defer s.deinit();

    const port = try s.bind("tcp://127.0.0.1:!");
    try std.testing.expect(port >= 0xC000);
}
