//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;
const tables = @import("tables");
const types = @import("types");

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test "tables has correct number of entries" {
    try testing.expect(tables.data0.offsets.len == types.code_point_range_end);
    try testing.expect(tables.data1.offsets.len == types.code_point_range_end);
}

test "ASCII 'A' has correct properties" {
    const a_offset0 = tables.data0.offsets[65]; // ASCII 'A'
    const a_data0 = tables.data0.data[a_offset0];
    try testing.expect(a_data0.case_folding_simple.toOptional() == 97); // 'a'

    const a_offset1 = tables.data1.offsets[65]; // ASCII 'A'
    const a_data1 = tables.data1.data[a_offset1];
    try testing.expect(a_data1.alphabetic == true);
    try testing.expect(a_data1.uppercase == true);
    try testing.expect(a_data1.lowercase == false);
}
