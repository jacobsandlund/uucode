//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;
const tables = @import("tables").tables;
const types = @import("types");

fn TableDataFor(comptime field_name: []const u8) type {
    for (tables) |table| {
        const DataArray = @FieldType(@TypeOf(table), "data");
        const Data = @typeInfo(DataArray).array.child;
        if (@hasField(Data, field_name)) {
            return @TypeOf(table);
        }
    }
    @compileError("Table not found for field: " ++ field_name);
}

fn tableFor(comptime field_name: []const u8) TableDataFor(field_name) {
    inline for (tables) |table| {
        const DataArray = @FieldType(@TypeOf(table), "data");
        const Data = @typeInfo(DataArray).array.child;
        if (@hasField(Data, field_name)) {
            return table;
        }
    }
    unreachable;
}

fn alphabetic(cp: u21) bool {
    const table = tableFor("alphabetic");
    return table.data[table.offsets[cp]].alphabetic;
}

fn generalCategory(cp: u21) types.GeneralCategory {
    const table = tableFor("general_category");
    return table.data[table.offsets[cp]].general_category;
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
