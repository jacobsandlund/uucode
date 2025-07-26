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

inline fn getData(comptime table: anytype, cp: u21) DataFor(table) {
    const stage1_idx = cp >> 8; // Top bits select block
    const stage2_idx = cp & 0xFF; // Bottom 8 bits select within block
    const block_start = table.stage1[stage1_idx] << 8;
    const data_idx = table.stage2[block_start + stage2_idx];
    return table.data[data_idx];
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
    const block_size = 256;
    const expected_stage1_size = (types.code_point_range_end + block_size - 1) / block_size;
    try testing.expect(tables.@"0".stage1.len == expected_stage1_size);
    try testing.expect(tables.@"1".stage1.len == expected_stage1_size);
}

test "ASCII 'A' has correct properties" {
    const a_data0 = getData(tables.@"0", 65); // ASCII 'A'
    try testing.expect(a_data0.case_folding_simple.toOptional() == 97); // 'a'

    const a_data1 = getData(tables.@"1", 65); // ASCII 'A'
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
