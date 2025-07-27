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

// TODO: benchmark if needing an explicit `inline`
fn getData(comptime table: anytype, cp: u21) DataFor(table) {
    const stage1_idx = cp >> 8;
    const stage2_idx = cp & 0xFF;
    const block_start = @as(usize, table.stage1[stage1_idx]) << 8;
    const data_idx = table.stage2[block_start + stage2_idx];
    return table.data[data_idx];
}

pub fn alphabetic(cp: u21) bool {
    const table = comptime tableFor("alphabetic");
    return getData(table, cp).alphabetic;
}

pub fn case_folding_simple(cp: u21) u21 {
    const table = comptime tableFor("case_folding_simple");
    return getData(table, cp).case_folding_simple.toOptional() orelse cp;
}

pub fn generalCategory(cp: u21) types.GeneralCategory {
    const table = comptime tableFor("general_category");
    return getData(table, cp).general_category;
}

test {
    std.testing.refAllDecls(@This());
}

test "alphabetic" {
    try testing.expect(alphabetic(65)); // 'A'
    try testing.expect(alphabetic(97)); // 'a'
    try testing.expect(!alphabetic(0));
}

test "case_folding_simple" {
    try testing.expectEqual(case_folding_simple(65), 97); // 'a'
    try testing.expectEqual(case_folding_simple(97), 97); // 'a'
}

// TODO: "tables" will need to have data for every field
//test "generalCategory" {
//    try testing.expect(generalCategory(65) == .Lu); // 'A'
//}
