//! This file defines the low(er)-level `get` method, returning `Data`.
//! (It also must be separate from `root.zig` so that `types.zig` can use it to
//! allow for a better `slice` API on `VarLen` fields.)
const std = @import("std");
const tables = @import("tables").tables;
const types = @import("types.zig");

fn TableData(comptime Table: anytype) type {
    const DataSlice = @FieldType(Table, "data");
    return @typeInfo(DataSlice).pointer.child;
}

fn tableInfoFor(comptime field: []const u8) std.builtin.Type.StructField {
    inline for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        if (@hasField(TableData(tableInfo.type), field)) {
            return tableInfo;
        }
    }

    @compileError("Table not found for field: " ++ field);
}

fn getTableInfo(comptime table_name: []const u8) std.builtin.Type.StructField {
    inline for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        if (std.mem.eql(u8, tableInfo.name, table_name)) {
            return tableInfo;
        }
    }

    @compileError("Table '" ++ table_name ++ "' not found in tables");
}

fn BackingFor(comptime field: []const u8) type {
    const tableInfo = tableInfoFor(field);
    const Backing = @FieldType(@FieldType(@TypeOf(tables), tableInfo.name), "backing");
    return @FieldType(@typeInfo(Backing).pointer.child, field);
}

pub fn backingFor(comptime field: []const u8) BackingFor(field) {
    const tableInfo = tableInfoFor(field);
    return @field(@field(tables, tableInfo.name).backing, field);
}

fn TableFor(comptime field: []const u8) type {
    const tableInfo = tableInfoFor(field);
    return @FieldType(@TypeOf(tables), tableInfo.name);
}

fn tableFor(comptime field: []const u8) TableFor(field) {
    return @field(tables, tableInfoFor(field).name);
}

fn GetTable(comptime table_name: []const u8) type {
    const tableInfo = getTableInfo(table_name);
    return @FieldType(@TypeOf(tables), tableInfo.name);
}

fn getTable(comptime table_name: []const u8) GetTable(table_name) {
    return @field(tables, getTableInfo(table_name).name);
}

// TODO: support two stage (stage1 and data) tables
fn data(comptime table: anytype, cp: u21) TableData(@TypeOf(table)) {
    const stage1_idx = cp >> 8;
    const stage2_idx = cp & 0xFF;
    return table.data[table.stage2[table.stage1[stage1_idx] + stage2_idx]];
}

pub fn getPacked(comptime table_name: []const u8, cp: u21) PackedTypeOf(table_name) {
    const table = comptime getTable(table_name);
    return data(table, cp);
}

pub fn PackedTypeOf(comptime table_name: []const u8) type {
    return TableData(getTableInfo(table_name).type);
}

const FieldEnum = blk: {
    var fields_len: usize = 0;
    for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        //// subtract 1 for _padding
        //fields_len += @typeInfo(TableData(table)).@"struct".fields.len - 1;
        fields_len += @typeInfo(TableData(tableInfo.type)).@"struct".fields.len;
    }

    var fields: [fields_len]std.builtin.Type.EnumField = undefined;
    var i: usize = 0;

    for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        for (@typeInfo(TableData(tableInfo.type)).@"struct".fields) |f| {
            //if (std.mem.eql(u8, f.name, "_padding")) continue;

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
    return @FieldType(TableData(tableInfoFor(field).type), field);
}

fn Field(comptime field: []const u8) type {
    const D = DataField(field);
    if (@typeInfo(D) == .@"struct" and (@hasDecl(D, "optional") or @hasDecl(D, "value"))) {
        if (@hasDecl(D, "optional") and (!@hasDecl(D, "is_optional") or D.is_optional)) {
            return ?D.T;
        } else if (@hasDecl(D, "value")) {
            return D.T;
        } else {
            return D;
        }
    } else {
        return D;
    }
}

fn getWithName(comptime name: []const u8, cp: u21) Field(name) {
    const D = DataField(name);

    if (@typeInfo(D) == .@"struct" and (@hasDecl(D, "optional") or @hasDecl(D, "value"))) {
        const table = comptime tableFor(name);
        const d = @field(data(table, cp), name);
        if (@hasDecl(D, "is_optional") and D.is_optional) {
            return d.optional(cp);
        } else if (@hasDecl(D, "optional") and !@hasDecl(D, "is_optional")) {
            return d.optional();
        } else {
            return d.value(cp);
        }
    } else {
        const table = comptime tableFor(name);
        return @field(data(table, cp), name);
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

    // `x` fields
    grapheme_break_x_emoji,
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
