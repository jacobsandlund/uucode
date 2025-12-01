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

/// Returns a custom iterator for a given Context type.
///
/// The Context must have the following methods:
///
/// * len(self: *Context) usize
/// * get(self: *Context, i: usize) ?u21
///
/// Even if `i` is less than the result of `len`, this still allows the
/// possibility of `get` returning null. The `len` just protects from
/// calling `get` with an `i` equal or greater the result of `len`.
pub fn CustomIterator(comptime Context: type) type {
    return struct {
        // This "i" is part of the documented API of this iterator, pointing to the
        // current location of the iterator in `code_points`.
        i: usize = 0,
        ctx: Context,

        const Self = @This();

        pub fn init(ctx: Context) Self {
            return .{
                .ctx = ctx,
            };
        }

        pub fn next(self: *Self) ?u21 {
            if (self.i >= self.ctx.len()) return null;
            defer self.i += 1;
            return self.ctx.get(self.i);
        }

        pub fn peek(self: Self) ?u21 {
            if (self.i >= self.ctx.len()) return null;
            return self.ctx.get(self.i);
        }
    };
}

test "CustomIterator for emoji code points" {
    const Wrapper = struct {
        cp: u21,
    };

    const code_points = &[_]Wrapper{
        .{ .cp = 0x1F600 }, // 😀
        .{ .cp = 0x1F605 }, // 😅
        .{ .cp = 0x1F63B }, // 😻
        .{ .cp = 0x1F47A }, // 👺
    };

    var it = CustomIterator(struct {
        points: []const Wrapper,

        pub fn len(self: @This()) usize {
            return self.points.len;
        }

        pub fn get(self: @This(), i: usize) u21 {
            return self.points[i].cp;
        }
    }).init(.{ .points = code_points });
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
