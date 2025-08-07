const std = @import("std");
const getpkg = @import("get.zig");
const types = @import("types.zig");
pub const ascii = @import("ascii.zig");
const testing = std.testing;

pub const get = getpkg.get;
pub const getPacked = getpkg.getPacked;

test {
    // TODO: "tables" will need to have data for every field
    //std.testing.refAllDecls(@This());
}

test "name" {
    var buffer = [_]u8{0} ** 88;
    try testing.expect(std.mem.eql(u8, get(.name, 65).slice(&buffer), "LATIN CAPITAL LETTER A"));
}

test "is_alphabetic" {
    try testing.expect(get(.is_alphabetic, 65)); // 'A'
    try testing.expect(get(.is_alphabetic, 97)); // 'a'
    try testing.expect(!get(.is_alphabetic, 0));
}

test "case_folding_simple" {
    try testing.expectEqual(97, get(.case_folding_simple, 65)); // 'a'
    try testing.expectEqual(97, get(.case_folding_simple, 97)); // 'a'
}

test "simple_uppercase_mapping" {
    try testing.expectEqual(65, get(.simple_uppercase_mapping, 97)); // 'a'
    try testing.expectEqual(null, get(.simple_uppercase_mapping, 65)); // 'A'
}

test "generalCategory" {
    try testing.expect(get(.general_category, 65) == .letter_uppercase); // 'A'
}

test "getPacked" {
    const d1 = getPacked("1", 65);
    try testing.expect(d1.is_alphabetic);
    try testing.expect(d1.is_uppercase);
    try testing.expect(!d1.is_lowercase);
}

test "get an extension field" {
    try testing.expectEqual(0, get(.foo, 65));
    try testing.expectEqual(3, get(.foo, 0));
}
