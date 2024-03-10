const std = @import("std");
const c = @import("../zmq.zig").c;

/// Version information of the `libzmq` in use.
pub const ZVersion = struct {
    major: u16,
    minor: u16,
    patch: u16,
};

/// Creates a new ZermoMQ context.
///
/// Multiple contextes can exist independently, e.g. for libraries.
///
/// A 0MQ 'context' is thread safe and may be shared among as many application threads as necessary,
/// without any additional locking required on the part of the caller.
pub const ZContext = struct {
    allocator_: std.mem.Allocator,
    ctx_: *anyopaque,

    pub fn init(allocator: std.mem.Allocator) !ZContext {
        // check the libzmq version 4.x
        if (ZContext.version().major != 4) {
            return error.LibZmqVersionMismatch;
        }

        // try creating the socket, early
        var s = c.zmq_ctx_new() orelse {
            switch (c.zmq_errno()) {
                c.EMFILE => return error.MaxOpenFilesExceeded,
                else => return error.ContextCreateFailed,
            }
        };
        errdefer {
            c.zmq_ctx_term(s);
        }

        // done
        return .{
            .allocator_ = allocator,
            .ctx_ = s,
        };
    }

    /// Destroy the socket and clean up
    pub fn deinit(self: *ZContext) void {
        _ = c.zmq_ctx_term(self.ctx_);
    }

    /// Returns the version of the `libzmq` shared library.
    pub fn version() ZVersion {
        var major: c_int = undefined;
        var minor: c_int = undefined;
        var patch: c_int = undefined;

        c.zmq_version(&major, &minor, &patch);

        return .{
            .major = @intCast(major),
            .minor = @intCast(minor),
            .patch = @intCast(patch),
        };
    }
};

test "ZContext - roundtrip" {
    const allocator = std.testing.allocator;

    var incoming = try ZContext.init(allocator);
    defer incoming.deinit();
}

test "ZContext - version" {
    const v = ZContext.version();

    std.log.info("Version: {}.{}.{}", .{ v.major, v.minor, v.patch });

    try std.testing.expectEqual(@as(u16, 4), v.major);
}
