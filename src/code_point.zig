const std = @import("std");

pub const Iterator = struct {
    // This "i" is part of the documented API of this iterator, pointing to the
    // current location of the iterator in `code_points`.
    i: usize = 0,
    code_points: []const u21,

    const Self = @This();

    pub fn init(code_points: []const u21) Self {
        return .{
            .code_points = code_points,
        };
    }

    pub fn next(self: *Self) ?u21 {
        if (self.i >= self.code_points.len) return null;
        defer self.i += 1;
        return self.code_points[self.i];
    }

    pub fn peek(self: Self) ?u21 {
        if (self.i >= self.code_points.len) return null;
        return self.code_points[self.i];
    }
};

test "Iterator for emoji code points" {
    const code_points = &[_]u21{
        0x1F600, // 😀
        0x1F605, // 😅
        0x1F63B, // 😻
        0x1F47A, // 👺
    };

    var it = Iterator.init(code_points);
    try std.testing.expectEqual(0x1F600, it.next());
    try std.testing.expectEqual(1, it.i);
    try std.testing.expectEqual(0x1F605, it.peek());
    try std.testing.expectEqual(1, it.i);
    try std.testing.expectEqual(0x1F605, it.next());
    try std.testing.expectEqual(2, it.i);
    try std.testing.expectEqual(0x1F63B, it.next());
    try std.testing.expectEqual(3, it.i);
    try std.testing.expectEqual(0x1F47A, it.next());
    try std.testing.expectEqual(4, it.i);
    try std.testing.expectEqual(null, it.next());
    try std.testing.expectEqual(4, it.i);
}
