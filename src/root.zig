//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;
const tables = @import("tables").tables;
const types = @import("types");

fn DataFor(comptime table: anytype) type {
    const DataArray = @FieldType(@TypeOf(table), "data");
    return @typeInfo(DataArray).array.child;
}

fn TableDataFor(comptime field: []const u8) type {
    for (tables) |table| {
        if (@hasField(DataFor(table), field)) {
            return @TypeOf(table);
        }
    }
    @compileError("Table not found for field: " ++ field);
}

fn tableFor(comptime field: []const u8) TableDataFor(field) {
    inline for (tables) |table| {
        if (@hasField(DataFor(table), field)) {
            return table;
        }
    }
    unreachable;
}

fn getData(comptime table: anytype, cp: u21) DataFor(table) {
    return table.data[table.offsets[cp]];
}

fn alphabetic(cp: u21) bool {
    const table = comptime tableFor("alphabetic");
    return getData(table, cp).alphabetic;
}

fn generalCategory(cp: u21) types.GeneralCategory {
    const table = comptime tableFor("general_category");
    return getData(table, cp).general_category;
}

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test {
    std.testing.refAllDecls(@This());
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test "tables has correct number of entries" {
    try testing.expect(tables.@"0".offsets.len == types.code_point_range_end);
    try testing.expect(tables.@"1".offsets.len == types.code_point_range_end);
}

test "ASCII 'A' has correct properties" {
    const a_offset0 = tables.@"0".offsets[65]; // ASCII 'A'
    const a_data0 = tables.@"0".data[a_offset0];
    try testing.expect(a_data0.case_folding_simple.toOptional() == 97); // 'a'

    const a_offset1 = tables.@"1".offsets[65]; // ASCII 'A'
    const a_data1 = tables.@"1".data[a_offset1];
    try testing.expect(a_data1.alphabetic == true);
    try testing.expect(a_data1.uppercase == true);
    try testing.expect(a_data1.lowercase == false);
}

test "alphabetic" {
    try testing.expect(alphabetic(65)); // 'A'
    try testing.expect(alphabetic(97)); // 'a'
    try testing.expect(!alphabetic(0));
}

// TODO: "tables" will need to have data for every field
//test "generalCategory" {
//    try testing.expect(generalCategory(65) == .Lu); // 'A'
//}
