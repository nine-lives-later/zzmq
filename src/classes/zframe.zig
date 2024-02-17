const std = @import("std");
const c = @import("../czmq.zig").c;

pub const ZFrame = struct {
    frame: *c.zframe_t,
    frameOwned: bool = true,

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
    pub fn data(self: *const ZFrame) ![]const u8 {
        if (!self.frameOwned) return error.FrameOwnershipLost;

        const s = c.zframe_size(self.frame);
        if (s <= 0) {
            return "";
        }

        const d = c.zframe_data(self.frame);

        return d[0..s];
    }

    /// Retrieves a size of data within the frame.
    pub fn size(self: *const ZFrame) !usize {
        if (!self.frameOwned) return error.FrameOwnershipLost;

        return c.zframe_size(self.frame);
    }

    /// Creates a copy of the frame.
    pub fn clone(self: *ZFrame) !ZFrame {
        if (!self.frameOwned) return error.FrameOwnershipLost;

        return ZFrame{
            .frame = c.zframe_dup(self.frame) orelse return error.FrameAllocFailed,
        };
    }

    /// When *receiving* frames of message, this function returns
    /// true, if more frames are available to be received,
    /// as part of a multi-part message.
    pub fn hasMore(self: *ZFrame) !bool {
        if (!self.frameOwned) return error.FrameOwnershipLost;

        return c.zframe_more(self.frame) != 0;
    }

    /// Destroys the frame and performs clean up.
    pub fn deinit(self: *ZFrame) void {
        if (self.frameOwned) {
            var d: ?*c.zframe_t = self.frame;

            c.zframe_destroy(&d);

            self.frameOwned = false;
        }
    }
};

test "ZFrame - create and destroy" {
    const msg = "hello world";

    var data = try ZFrame.init(msg);
    defer data.deinit();

    try std.testing.expectEqual(msg.len, try data.size());
    try std.testing.expectEqualStrings(msg, try data.data());

    // create and test a clone
    var clone = try data.clone();
    defer clone.deinit();

    try std.testing.expectEqual(msg.len, try clone.size());
    try std.testing.expectEqualStrings(msg, try clone.data());
}

test "ZFrame - empty and destroy" {
    var data = try ZFrame.initEmpty();
    defer data.deinit();

    try std.testing.expectEqual(@as(usize, 0), try data.size());
    try std.testing.expectEqualStrings("", try data.data());

    // create and test a clone
    var clone = try data.clone();
    defer clone.deinit();

    try std.testing.expectEqual(@as(usize, 0), try clone.size());
    try std.testing.expectEqualStrings("", try clone.data());
}

test "ZFrame - ownership lost" {
    var data = try ZFrame.initEmpty();
    defer data.deinit();

    try std.testing.expectEqual(true, data.frameOwned);
    try std.testing.expectEqual(@as(usize, 0), try data.size());

    // force loosing ownership
    data.frameOwned = false;

    try std.testing.expectError(error.FrameOwnershipLost, data.size());
    try std.testing.expectError(error.FrameOwnershipLost, data.data());
    try std.testing.expectError(error.FrameOwnershipLost, data.clone());
    try std.testing.expectError(error.FrameOwnershipLost, data.hasMore());
}
