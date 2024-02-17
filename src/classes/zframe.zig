const std = @import("std");
const c = @import("../czmq.zig").c;

pub const ZFrame = struct {
    frame: *c.zframe_t,

    /// Creates a frame based on the provided data.
    ///
    /// The data is being copied into the frame.
    pub fn init(d: []const u8) !ZFrame {
        return ZFrame{
            .frame = c.zframe_new(&d[0], d.len) orelse return error.FrameAllocFailed,
        };
    }

    /// Creates an empty frame, e.g. for delimiter frames.
    pub fn initEmpty() !ZFrame {
        return ZFrame{
            .frame = c.zframe_new_empty() orelse return error.FrameAllocFailed,
        };
    }

    /// Retrieves a slice to the data stored within the frame.
    ///
    /// Example:
    ///    allocator.dupe(u8, frame.data());
    pub fn data(self: *const ZFrame) []const u8 {
        const s = c.zframe_size(self.frame);
        if (s <= 0) {
            return "";
        }

        const d = c.zframe_data(self.frame);

        return d[0..s];
    }

    /// Retrieves a size of data within the frame.
    pub fn size(self: *const ZFrame) usize {
        return c.zframe_size(self.frame);
    }

    /// Creates a copy of the frame.
    pub fn clone(self: *ZFrame) !ZFrame {
        return ZFrame{
            .frame = c.zframe_dup(self.frame) orelse return error.FrameAllocFailed,
        };
    }

    /// Destroys the frame and performs clean up.
    pub fn deinit(self: *ZFrame) void {
        var d: ?*c.zframe_t = self.frame;

        c.zframe_destroy(&d);
    }
};

test "ZFrame - create and destroy" {
    const msg = "hello world";

    var data = try ZFrame.init(msg);
    defer data.deinit();

    try std.testing.expectEqual(msg.len, data.size());
    try std.testing.expectEqualStrings(msg, data.data());

    // create and test a clone
    var clone = try data.clone();
    defer clone.deinit();

    try std.testing.expectEqual(msg.len, clone.size());
    try std.testing.expectEqualStrings(msg, clone.data());
}

test "ZFrame - empty and destroy" {
    var data = try ZFrame.initEmpty();
    defer data.deinit();

    try std.testing.expectEqual(@as(usize, 0), data.size());
    try std.testing.expectEqualStrings("", data.data());

    // create and test a clone
    var clone = try data.clone();
    defer clone.deinit();

    try std.testing.expectEqual(@as(usize, 0), clone.size());
    try std.testing.expectEqualStrings("", clone.data());
}
