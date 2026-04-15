//! This file defines the low(er)-level `get` method, returning `Data`.
const std = @import("std");
const tables_module = @import("tables");
const tables = tables_module.tables;

fn TableData(comptime Table: anytype) type {
    const DataSlice = if (@hasField(Table, "stage3"))
        @FieldType(Table, "stage3")
    else
        @FieldType(Table, "stage2");
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

pub fn hasField(comptime field: []const u8) bool {
    inline for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        if (@hasField(TableData(tableInfo.type), field)) {
            return true;
        }
    }

    return false;
}

fn BackingFor(comptime field: []const u8) type {
    return @FieldType(tables_module.Backing, field);
}

pub fn backingFor(comptime field: []const u8) BackingFor(field) {
    return @field(tables_module.backing, field);
}

fn TableFor(comptime field: []const u8) type {
    const tableInfo = tableInfoFor(field);
    return @FieldType(@TypeOf(tables), tableInfo.name);
}

fn tableFor(comptime field: []const u8) TableFor(field) {
    return @field(tables, tableInfoFor(field).name);
}

fn GetTable(comptime table_name: []const u8) type {
    inline for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        if (std.mem.eql(u8, tableInfo.name, table_name)) {
            return tableInfo.type;
        }
    }

    @compileError("Table '" ++ table_name ++ "' not found in tables");
}

fn getTable(comptime table_name: []const u8) GetTable(table_name) {
    return @field(tables, table_name);
}

fn data(comptime table: anytype, cp: u21) TableData(@TypeOf(table)) {
    const stage1_idx = cp >> 8;
    const stage2_idx = cp & 0xFF;
    if (@hasField(@TypeOf(table), "stage3")) {
        return table.stage3[table.stage2[table.stage1[stage1_idx] + stage2_idx]];
    } else {
        return table.stage2[table.stage1[stage1_idx] + stage2_idx];
    }
}

pub fn getAll(comptime table_name: []const u8, cp: u21) TypeOfAll(table_name) {
    const table = comptime getTable(table_name);
    return data(table, cp);
}

pub fn TypeOfAll(comptime table_name: []const u8) type {
    return TableData(GetTable(table_name));
}

pub const FieldEnum = blk: {
    var fields_len: usize = 0;
    for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        fields_len += @typeInfo(TableData(tableInfo.type)).@"struct".fields.len;
    }

    const TagInt = std.math.IntFittingRange(0, fields_len - 1);
    var field_names: [fields_len][]const u8 = undefined;
    var field_values: [fields_len]TagInt = undefined;
    var i: usize = 0;

    for (@typeInfo(@TypeOf(tables)).@"struct".fields) |tableInfo| {
        for (@typeInfo(TableData(tableInfo.type)).@"struct".fields) |f| {
            field_names[i] = f.name;
            field_values[i] = i;
            i += 1;
        }
    }

    break :blk @Enum(TagInt, .exhaustive, &field_names, &field_values);
};

fn DataField(comptime field: []const u8) type {
    return @FieldType(TableData(tableInfoFor(field).type), field);
}

pub fn WithBacking(comptime S: type) type {
    const T = @typeInfo(S.Backing).pointer.child;
    return struct {
        slice: S,
        backing: S.Backing,

        pub fn with(self: *const @This(), single_item_buffer: *[1]T, cp: u21) []const T {
            return self.slice.valueWith(self.backing, single_item_buffer, cp);
        }
    };
}

fn FieldValue(comptime field: []const u8) type {
    const D = DataField(field);
    if (@typeInfo(D) == .@"struct") {
        if (@hasDecl(D, "unshift") and @TypeOf(D.unshift) != void) {
            return @typeInfo(@TypeOf(D.unshift)).@"fn".return_type.?;
        } else if (@hasDecl(D, "unpack")) {
            return @typeInfo(@TypeOf(D.unpack)).@"fn".return_type.?;
        } else if (@hasDecl(D, "value") and @TypeOf(D.value) != void) {
            return @typeInfo(@TypeOf(D.value)).@"fn".return_type.?;
        } else if (@hasDecl(D, "Backing")) {
            return WithBacking(D);
        } else {
            return D;
        }
    } else {
        return D;
    }
}

// Note: I tried using a union with members that are the known types, and using
// @FieldType(KnownFieldsForLspUnion, field) but the LSP was still unable to
// figure out the type. It seems like the only way to get the LSP to know the
// type would be having dedicated `get` functions for each field, but I don't
// want to go that route.
pub fn get(comptime field: FieldEnum, cp: u21) TypeOf(field) {
    const name = @tagName(field);
    const D = DataField(name);
    const table = comptime tableFor(name);

    if (@typeInfo(D) == .@"struct" and (@hasDecl(D, "unpack") or @hasDecl(D, "unshift") or @hasDecl(D, "Backing"))) {
        const d = @field(data(table, cp), name);
        if (@hasDecl(D, "unshift") and @TypeOf(D.unshift) != void) {
            return d.unshift(cp);
        } else if (@hasDecl(D, "unpack")) {
            return d.unpack();
        } else if (@hasDecl(D, "value") and @TypeOf(D.value) != void) {
            return d.value(backingFor(name));
        } else {
            return .{ .slice = d, .backing = backingFor(name) };
        }
    } else {
        return @field(data(table, cp), name);
    }
}

pub fn TypeOf(comptime field: FieldEnum) type {
    return FieldValue(@tagName(field));
}
