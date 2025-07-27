const std = @import("std");
const testing = std.testing;
const tables = @import("table_data").tables;
const types = @import("types.zig");

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

// TODO: benchmark if needing an explicit `inline`
// TODO: support two stage (stage1 and data) tables
fn getData(comptime table: anytype, cp: u21) DataFor(table) {
    const stage1_idx = cp >> 8;
    const stage2_idx = cp & 0xFF;
    const block_start = @as(usize, table.stage1[stage1_idx]) << 8;
    const data_idx = table.stage2[block_start + stage2_idx];
    return table.data[data_idx];
}

pub fn data(comptime table_index: []const u8, cp: u21) DataFor(@field(tables, table_index)) {
    const table = @field(tables, table_index);
    return getData(table, cp);
}

pub fn isAlphabetic(cp: u21) bool {
    const table = comptime tableFor("is_alphabetic");
    return getData(table, cp).is_alphabetic;
}

pub fn caseFoldingSimple(cp: u21) u21 {
    const table = comptime tableFor("case_folding_simple");
    return getData(table, cp).case_folding_simple.toOptional() orelse cp;
}

pub fn generalCategory(cp: u21) types.GeneralCategory {
    const table = comptime tableFor("general_category");
    return getData(table, cp).general_category;
}

test {
    // TODO: "tables" will need to have data for every field
    //std.testing.refAllDecls(@This());
}

test "isAlphabetic" {
    try testing.expect(isAlphabetic(65)); // 'A'
    try testing.expect(isAlphabetic(97)); // 'a'
    try testing.expect(!isAlphabetic(0));
}

test "caseFoldingSimple" {
    try testing.expectEqual(caseFoldingSimple(65), 97); // 'a'
    try testing.expectEqual(caseFoldingSimple(97), 97); // 'a'
}

// TODO: "tables" will need to have data for every field
//test "generalCategory" {
//    try testing.expect(generalCategory(65) == .Lu); // 'A'
//}
