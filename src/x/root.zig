const std = @import("std");
pub const types_x = @import("types.x.zig");
pub const grapheme = @import("grapheme.zig");
const testing = std.testing;

// wcwidth tests

test "wcwidth emoji_modifier is 2" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x1F3FF)); // 🏿
}
