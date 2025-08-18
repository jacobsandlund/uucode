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

fn GetTable(comptime table_name: []const u8) type {
    for (tables) |table| {
        if (std.mem.eql(u8, table.name, table_name)) {
            return @TypeOf(table);
        }
    }

    @compileError("Table '" ++ table_name ++ "' not found in tables");
}

fn getTable(comptime table_name: []const u8) GetTable(table_name) {
    for (tables) |table| {
        if (std.mem.eql(u8, table.name, table_name)) {
            return table;
        }
    }
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

pub fn getPacked(comptime table_name: []const u8, cp: u21) PackedTypeOf(table_name) {
    const table = comptime getTable(table_name);
    return data(table, cp);
}

pub fn PackedTypeOf(comptime table_name: []const u8) type {
    return DataFor(getTable(table_name));
}

const FieldEnum = blk: {
    var fields_len: usize = 0;
    for (tables) |table| {
        // subtract 1 for _padding
        fields_len += @typeInfo(DataFor(table)).@"struct".fields.len - 1;
    }

    var fields: [fields_len]std.builtin.Type.EnumField = undefined;
    var i: usize = 0;

    for (tables) |table| {
        for (@typeInfo(DataFor(table)).@"struct".fields) |f| {
            if (std.mem.eql(u8, f.name, "_padding")) continue;

            fields[i] = .{
                .name = f.name,
                .value = i,
            };
            i += 1;
        }
    }

    break :blk @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, fields_len - 1),
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = true,
        },
    });
};

fn DataField(comptime field: []const u8) type {
    return @FieldType(DataFor(tableFor(field)), field);
}

fn Field(comptime field: []const u8) type {
    const D = DataField(field);
    switch (@typeInfo(D)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {
            if (@hasDecl(D, "optional") and (!@hasDecl(D, "is_optional") or D.is_optional)) {
                return ?D.T;
            } else if (@hasDecl(D, "value")) {
                return D.T;
            } else {
                return D;
            }
        },
        else => return D,
    }
}

inline fn getWithName(comptime name: []const u8, cp: u21) Field(name) {
    const D = DataField(name);
    const table = comptime tableFor(name);
    const d = @field(data(table, cp), name);

    switch (@typeInfo(D)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {
            if (@hasDecl(D, "is_optional") and D.is_optional) {
                return d.optional(cp);
            } else if (@hasDecl(D, "optional") and !@hasDecl(D, "is_optional")) {
                return d.optional();
            } else if (@hasDecl(D, "value")) {
                return d.value(cp);
            } else {
                return d;
            }
        },
        else => return d,
    }
}

// Note: `getX` and `TypeOfX` are only needed because `get` and`TypeOf` use a
// known field enum so that the LSP can complete the field names, and for user
// extensions we wouldn't know all the field names. If the LSP ever gets smart
// enough to figure out all the field names, we can replace `get` with `getX`
// and `TypeOf` with `TypeOfX` and lose the hardcoded `KnownFieldsForLsp`.
pub fn getX(comptime field: FieldEnum, cp: u21) TypeOfX(field) {
    return getWithName(@tagName(field), cp);
}

pub fn TypeOfX(comptime field: FieldEnum) type {
    return Field(@tagName(field));
}

pub const KnownFieldsForLsp = enum {
    // UnicodeData fields
    name,
    general_category,
    canonical_combining_class,
    bidi_class,
    decomposition_type,
    decomposition_mapping,
    numeric_type,
    numeric_value_decimal,
    numeric_value_digit,
    numeric_value_numeric,
    is_bidi_mirrored,
    unicode_1_name,
    simple_uppercase_mapping,
    simple_lowercase_mapping,
    simple_titlecase_mapping,

    // CaseFolding fields
    case_folding_simple,
    case_folding_turkish,
    case_folding_full,

    // SpecialCasing fields
    special_lowercase_mapping,
    special_titlecase_mapping,
    special_uppercase_mapping,
    special_casing_condition,

    // DerivedCoreProperties fields
    is_math,
    is_alphabetic,
    is_lowercase,
    is_uppercase,
    is_cased,
    is_case_ignorable,
    changes_when_lowercased,
    changes_when_uppercased,
    changes_when_titlecased,
    changes_when_casefolded,
    changes_when_casemapped,
    is_id_start,
    is_id_continue,
    is_xid_start,
    is_xid_continue,
    is_default_ignorable_code_point,
    is_grapheme_extend,
    is_grapheme_base,
    is_grapheme_link,
    indic_conjunct_break,

    // EastAsianWidth field
    east_asian_width,

    // OriginalGraphemeBreak field
    original_grapheme_break,

    // EmojiData fields
    is_emoji,
    is_emoji_presentation,
    is_emoji_modifier,
    is_emoji_modifier_base,
    is_emoji_component,
    is_extended_pictographic,

    // GraphemeBreak field (derived)
    grapheme_break,

    // Block field
    block,

    // gib.x fields
    wcwidth,
};

// Note: I tried using a union with members that are the known types, and using
// @FieldType(KnownFieldsForLspUnion, field) but the LSP was still unable to
// figure out the type. It seems like the only way to get the LSP to know the
// type would be having dedicated `get` functions for each field, but I don't
// want to go that route.
pub fn get(comptime field: KnownFieldsForLsp, cp: u21) TypeOf(field) {
    return getWithName(@tagName(field), cp);
}

pub fn TypeOf(comptime field: KnownFieldsForLsp) type {
    return Field(@tagName(field));
}

// TODO: figure out how to get the build to test this file (tests are in root.zig)
