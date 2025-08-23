const std = @import("std");

// See https://bjoern.hoehrmann.de/utf-8/decoder/dfa/
// and licenses/LICENSE_Bjoern_Hoehrmann

const UTF8_ACCEPT = 0;
const UTF8_REJECT = 12;

// The first part of the table maps bytes to character classes to reduce the
// size of the transition table and create bitmasks.
const utf8d = [_]u8{
    0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1,  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 9,  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
    7,  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    8,  8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3, 11, 6, 6, 6, 5, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
};

// The second part is a transition table that maps a combination of a state of
// the automaton and a character class to a state.
const state_utf8d = [_]u8{
    0,  12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 0,  12, 12, 12, 12, 12, 0,
    12, 0,  12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 12,
    12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12,
    12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
};

fn decodeByte(state: *usize, cp: *u21, byte: u8) bool {
    const class: std.math.IntFittingRange(0, 11) = @intCast(utf8d[byte]);
    const mask: u21 = 0xff;

    cp.* = if (state.* != UTF8_ACCEPT)
        (byte & 0x3f) | (cp.* << 6)
    else
        (mask >> class) & byte;

    state.* = state_utf8d[state.* + class];
    return state.* == UTF8_ACCEPT;
}

pub const CodePointIterator = struct {
    bytes: []const u8,
    i: usize = 0,

    const Self = @This();

    pub fn init(bytes: []const u8) Self {
        return .{
            .bytes = bytes,
        };
    }

    pub fn next(self: *Self) ?u21 {
        if (self.i >= self.bytes.len) return null;

        var cp: u21 = 0;
        var state: usize = UTF8_ACCEPT;
        while (self.i < self.bytes.len and
            !decodeByte(&state, &cp, self.bytes[self.i])) : (self.i += 1)
        {}

        if (state == UTF8_ACCEPT) {
            self.i += 1;
            return cp;
        } else {
            return null;
        }
    }

    pub fn peek(self: Self) ?u21 {
        var iter = self;
        return iter.next();
    }
};

test "CodePointIterator for ascii" {
    var iter = CodePointIterator.init("abc");
    try std.testing.expectEqual('a', iter.next());
    try std.testing.expectEqual(1, iter.i);
    try std.testing.expectEqual('b', iter.peek());
    try std.testing.expectEqual('b', iter.next());
    try std.testing.expectEqual('c', iter.next());
    try std.testing.expectEqual(null, iter.peek());
    try std.testing.expectEqual(null, iter.next());
}

test "CodePointIterator for emoji" {
    var iter = CodePointIterator.init("😀😅😻👺");
    try std.testing.expectEqual(0x1F600, iter.next());
    try std.testing.expectEqual(0x1F605, iter.next());
    try std.testing.expectEqual(0x1F63B, iter.next());
    try std.testing.expectEqual(0x1F47A, iter.next());
}
