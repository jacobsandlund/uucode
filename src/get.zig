//! This file defines the low(er)-level `get` method, returning `Data`.
//! (It also must be separate from `root.zig` so that `types.zig` can use it to
//! allow for a better `slice` API on `VarLen` fields.)
const std = @import("std");
const testing = std.testing;
const tables = @import("tables").tables;
const types = @import("types.zig");

fn DataFor(comptime table: anytype) type {
    const DataArray = @FieldType(@TypeOf(table), "data");
    return @typeInfo(DataArray).array.child;
}

fn TableFor(comptime field: []const u8) type {
    for (tables) |table| {
        if (@hasField(DataFor(table), field)) {
            return @TypeOf(table);
        }
    }
    @compileError("Table not found for field: " ++ field);
}

pub fn tableFor(comptime field: []const u8) TableFor(field) {
    inline for (tables) |table| {
        if (@hasField(DataFor(table), field)) {
            return table;
        }
    }
    unreachable;
}

fn DataField(comptime field: []const u8) type {
    return @FieldType(DataFor(tableFor(field)), field);
}

// TODO: benchmark if needing an explicit `inline`
// TODO: support two stage (stage1 and data) tables
fn data(comptime table: anytype, cp: u21) DataFor(table) {
    const stage1_idx = cp >> 8;
    const stage2_idx = cp & 0xFF;
    const block_start = @as(usize, table.stage1[stage1_idx]) << 8;
    const data_idx = table.stage2[block_start + stage2_idx];
    return table.data[data_idx];
}

pub fn getPacked(comptime table_index: []const u8, cp: u21) DataFor(@field(tables, table_index)) {
    const table = @field(tables, table_index);
    return data(table, cp);
}

pub fn Field(comptime field: []const u8) type {
    const D = DataField(field);
    switch (@typeInfo(D)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {
            if (@hasDecl(D, "optional")) {
                if (D.default_to_cp)
                    return D.T
                else
                    return ?D.T;
            } else {
                return D;
            }
        },
        else => return D,
    }
}

pub fn get(comptime field: []const u8, cp: u21) Field(field) {
    const D = DataField(field);
    const table = comptime tableFor(field);
    const d = @field(data(table, cp), field);

    switch (@typeInfo(D)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {
            if (@hasDecl(D, "optional")) {
                if (D.default_to_cp) {
                    return d.optional() orelse cp;
                } else {
                    return d.optional();
                }
            } else {
                return d;
            }
        },
        else => return d,
    }
}

// TODO: figure out how to get the build to test this file (tests are in root.zig)
