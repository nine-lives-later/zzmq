const std = @import("std");
const c = @import("../zmq.zig").c;

const ZMessageType = enum {
    /// The message content memory is managed internally by Zig.
    ///
    /// Since the content is reference-counted, it is safe
    /// to call `deinit()` after queueing its content for sending.
    ///
    /// The main use case is outgoing messages.
    Internal,

    /// The message content memory is managed by libzmq.
    ///
    /// Since the content ownership is tracked, it is safe to
    /// call `deinit()` after queueing its content for sending.
    ///
    /// The main use case is incoming messages.
    External,
};

const ZMessageImpl = union(ZMessageType) {
    Internal: ZMessageInternal,
    External: ZMessageExternal,
};

pub const ZMessage = struct {
    impl_: ZMessageImpl,

    /// Creates a message based on the provided data.
    ///
    /// The data is being copied into the message.
    pub fn init(allocator: std.mem.Allocator, d: []const u8) !ZMessage {
        return .{ .impl_ = .{
            .Internal = try ZMessageInternal.init(allocator, d),
        } };
    }

    /// Creates a message based on the provided data.
    ///
    /// If an allocator is provided, it will be used to free
    /// the provided data. If not, the caller is responsible for
    /// freeing the memory at some point.
    pub fn initUnmanaged(d: []const u8, allocator: ?std.mem.Allocator) !ZMessage {
        return .{ .impl_ = .{
            .Internal = try ZMessageInternal.initUnmanaged(d, allocator),
        } };
    }

    /// Takes the ownership over the provided raw message.
    ///
    /// Note: the message argument must be initalized, using `zmq_msg_init()` or other similar functions.
    ///
    /// The ownership can be lost when sending the message.
    pub fn initExternal(message: *c.zmq_msg_t) !ZMessage {
        return .{ .impl_ = .{
            .External = try ZMessageExternal.init(message),
        } };
    }

    /// Creates an empty message, e.g. for delimiters.
    ///
    /// The ownership can be lost when sending the message.
    pub fn initExternalEmpty() !ZMessage {
        return .{ .impl_ = .{
            .External = try ZMessageExternal.initEmpty(),
        } };
    }

    /// Retrieves a slice to the data stored within the message.
    pub fn data(self: *const ZMessage) ![]const u8 {
        switch (self.impl_) {
            .Internal => return self.impl_.Internal.data(),
            .External => return try self.impl_.External.data(),
        }
    }

    /// Retrieves a size of data within the message.
    pub fn size(self: *const ZMessage) !usize {
        switch (self.impl_) {
            .Internal => return self.impl_.Internal.size(),
            .External => return try self.impl_.External.size(),
        }
    }

    /// Allocates (or moves ownership of) external representation the message.
    ///
    /// This is used for tranferring ownership of data to ZeroMQ internal functions
    /// like `zmq_msg_send()`.
    pub fn allocExternal(self: *ZMessage) !ZMessageExternal {
        switch (self.impl_) {
            .Internal => return try self.impl_.Internal.allocExternal(),
            .External => {
                const cpy = self.impl_.External;

                self.impl_.External.msgOwned_ = false; // ownership moved away

                return cpy;
            },
        }
    }

    /// Destroys the message and performs clean up.
    pub fn deinit(self: *ZMessage) void {
        switch (self.impl_) {
            .Internal => self.impl_.Internal.deinit(),
            .External => self.impl_.External.deinit(),
        }
    }
};

const ZMessageInternal = struct {
    data_: []const u8,
    refCounter_: usize = 1, // starting with Zig 0.12, replace by std.Thread.Atomic(usize)
    allocator_: ?std.mem.Allocator = null,

    /// Creates a message based on the provided data.
    ///
    /// The data is being copied into the message.
    pub fn init(allocator: std.mem.Allocator, d: []const u8) !ZMessageInternal {
        const d2 = try allocator.dupe(u8, d);
        errdefer allocator.free(d2);

        return try initUnmanaged(d2, allocator);
    }

    /// Creates a message based on the provided data.
    ///
    /// If an allocator is provided, it will be used to free
    /// the provided data. If not, the caller is responsible for
    /// freeing the memory at some point.
    pub fn initUnmanaged(d: []const u8, allocator: ?std.mem.Allocator) !ZMessageInternal {
        return .{
            .data_ = d,
            .allocator_ = allocator,
        };
    }

    fn allocExternalFree(d: ?*anyopaque, hint: ?*anyopaque) callconv(.C) void {
        _ = d;

        var r: *ZMessageInternal = @alignCast(@ptrCast(hint.?));

        r.refRelease();
    }

    /// Creates a new external message object which points to the
    /// data stored within this internal message.
    pub fn allocExternal(self: *ZMessageInternal) !ZMessageExternal {
        var message: c.zmq_msg_t = undefined;

        if (self.data_.len <= 0) {
            const result = c.zmq_msg_init(&message);
            if (result < 0) {
                return error.FrameInitFailed;
            }
        } else {
            const result = c.zmq_msg_init_data(&message, @constCast(&self.data_[0]), self.data_.len, &allocExternalFree, self);
            if (result < 0) {
                return error.FrameInitFailed;
            }
        }

        self.refAdd(); // increase reference count

        return try ZMessageExternal.init(&message);
    }

    /// Retrieves a slice to the data stored within the message.
    pub fn data(self: *const ZMessageInternal) []const u8 {
        return self.data_;
    }

    /// Retrieves a size of data within the message.
    pub fn size(self: *const ZMessageInternal) usize {
        return self.data_.len;
    }

    fn refAdd(self: *ZMessageInternal) void {
        _ = @atomicRmw(usize, &self.refCounter_, .Add, 1, .seq_cst);
    }

    fn refRelease(self: *ZMessageInternal) void {
        const prev = @atomicRmw(usize, &self.refCounter_, .Sub, 1, .seq_cst);

        if (prev == 1) { // it's now zero
            if (self.allocator_) |a| {
                a.free(self.data_);
            }
        }
    }

    /// Destroys the message and performs clean up.
    pub fn deinit(self: *ZMessageInternal) void {
        self.refRelease();
    }
};

test "ZMessageInternal - create and destroy" {
    const allocator = std.testing.allocator;
    const msg = "hello world";

    var data = try ZMessageInternal.init(allocator, msg);
    defer data.deinit();

    try std.testing.expectEqual(msg.len, data.size());
    try std.testing.expectEqualStrings(msg, data.data());
}

test "ZMessageInternal - create unmanaged" {
    const allocator = std.testing.allocator;
    const msg = try allocator.dupe(u8, "Hello World!"); // duplicate to track the memory
    defer allocator.free(msg);

    var data = try ZMessageInternal.initUnmanaged(msg, null);
    defer data.deinit();

    try std.testing.expectEqual(msg.len, data.size());
    try std.testing.expectEqualStrings(msg, data.data());
}

const ZMessageExternal = struct {
    msg_: c.zmq_msg_t,
    msgOwned_: bool = true,

    /// Takes the ownership over the provided raw message.
    ///
    /// Note: the message argument must be initalized, using `zmq_msg_init()` or other similar functions.
    pub fn init(message: *c.zmq_msg_t) !ZMessageExternal {
        return .{
            .msg_ = message.*,
        };
    }

    /// Creates an empty message, e.g. for delimiters.
    pub fn initEmpty() !ZMessageExternal {
        var r = ZMessageExternal{
            .msg_ = undefined,
        };

        const result = c.zmq_msg_init(&r.msg_);
        if (result < 0) {
            return error.MessageAllocFailed;
        }

        return r;
    }

    /// Retrieves a slice to the data stored within the message.
    ///
    /// Example:
    ///    allocator.dupe(u8, message.data());
    pub fn data(self: *const ZMessageExternal) ![]const u8 {
        if (!self.msgOwned_) return error.MessageOwnershipLost;

        const m: *c.zmq_msg_t = @constCast(&self.msg_);
        const s = c.zmq_msg_size(m);
        if (s <= 0) {
            return "";
        }

        const d = c.zmq_msg_data(m).?;
        const dd: [*c]u8 = @ptrCast(d);

        return dd[0..s];
    }

    /// Retrieves a size of data within the message.
    pub fn size(self: *const ZMessageExternal) !usize {
        if (!self.msgOwned_) return error.MessageOwnershipLost;

        const m: *c.zmq_msg_t = @constCast(&self.msg_);

        return c.zmq_msg_size(m);
    }

    /// Moves ownership of raw representation of the message.
    ///
    /// The returned object must either be freed by using `c.zmq_msg_close()`
    /// or by providing it to functions like `c.zmq_msg_send()`.
    pub fn move(self: *ZMessageExternal) ![*c]c.zmq_msg_t {
        if (!self.msgOwned_) return error.MessageOwnershipLost;

        self.msgOwned_ = false;

        return &self.msg_; // returning a pointer is fine, here
    }

    /// Retakes ownership of raw representation of the message.
    ///
    /// This is used to retake ownership in some corner cases,
    /// like failed `c.zmq_msg_send()` calls.
    pub fn unmove(self: *ZMessageExternal) void {
        self.msgOwned_ = true;
    }

    /// Destroys the message and performs clean up.
    pub fn deinit(self: *ZMessageExternal) void {
        if (self.msgOwned_) {
            _ = c.zmq_msg_close(&self.msg_);

            self.msgOwned_ = false;
        }
    }
};

test "ZMessageExternal - ownership lost" {
    var data = try ZMessageExternal.initEmpty();
    defer data.deinit();

    try std.testing.expectEqual(true, data.msgOwned_);
    try std.testing.expectEqual(@as(usize, 0), try data.size());

    // force loosing ownership
    data.msgOwned_ = false;
    defer data.msgOwned_ = true; // restore ownership to not leak memory

    try std.testing.expectError(error.MessageOwnershipLost, data.size());
    try std.testing.expectError(error.MessageOwnershipLost, data.data());
}
