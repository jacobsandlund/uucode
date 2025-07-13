//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;
const tables = @import("tables");
const data = @import("data");

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test "tables has correct number of entries" {
    try testing.expect(tables.table.len == data.num_code_points);
}

test "ASCII 'A' has correct properties" {
    const a_offset = tables.table[65]; // ASCII 'A'
    const a_data = tables.selected_data[a_offset];
    try testing.expect(a_data.case_folding_simple == 97); // 'a'
}

//test "ASCII '0' has correct properties" {
//    const zero_data = tables.table[48]; // ASCII '0'
//    try testing.expect(zero_data.unicode_data.general_category == .Nd);
//    try testing.expect(zero_data.unicode_data.bidi_class == .EN);
//}
