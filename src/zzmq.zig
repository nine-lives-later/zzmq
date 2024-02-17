const std = @import("std");

pub const zsocket = @import("classes/zsocket.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
