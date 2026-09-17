//! The `(used)` markers in `ucd/.gitignore` declare which UCD files the table
//! generator reads. `build.zig` registers those files as inputs of the
//! generate step so that editing one regenerates the tables, and the
//! generator refuses to read a file that isn't declared, so the two can't
//! silently drift apart.
const std = @import("std");

pub const UsedIterator = struct {
    lines: std.mem.SplitIterator(u8, .scalar),

    /// Returns the next path relative to `ucd/`.
    pub fn next(self: *UsedIterator) ?[]const u8 {
        while (self.lines.next()) |line| {
            const entry = std.mem.trim(u8, line, " \t\r");
            if (!std.mem.startsWith(u8, entry, "#") or
                !std.mem.endsWith(u8, entry, "(used)")) continue;
            return std.mem.trim(u8, entry[1 .. entry.len - "(used)".len], " \t");
        }
        return null;
    }
};

pub fn iterateUsed(gitignore: []const u8) UsedIterator {
    return .{ .lines = std.mem.splitScalar(u8, gitignore, '\n') };
}

pub fn isUsed(gitignore: []const u8, ucd_relative_path: []const u8) bool {
    var it = iterateUsed(gitignore);
    while (it.next()) |path| {
        if (std.mem.eql(u8, path, ucd_relative_path)) return true;
    }
    return false;
}

test "iterateUsed" {
    const gitignore =
        \\# comment
        \\ArabicShaping.txt
        \\# BidiBrackets.txt (used)
        \\#  emoji/emoji-data.txt  (used)
        \\# auxiliary/GraphemeBreakTest.txt (only used for tests)
        \\# extracted/DerivedGeneralCategory.txt (unused, but useful for reference)
        \\
    ;
    var it = iterateUsed(gitignore);
    try std.testing.expectEqualStrings("BidiBrackets.txt", it.next().?);
    try std.testing.expectEqualStrings("emoji/emoji-data.txt", it.next().?);
    try std.testing.expectEqual(null, it.next());

    try std.testing.expect(isUsed(gitignore, "BidiBrackets.txt"));
    try std.testing.expect(!isUsed(gitignore, "ArabicShaping.txt"));
    try std.testing.expect(!isUsed(gitignore, "auxiliary/GraphemeBreakTest.txt"));
}
