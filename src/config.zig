const std = @import("std");
const types = @import("types.zig");

pub const max_code_point: u21 = 0x10FFFF;
pub const code_point_range_end: u21 = max_code_point + 1;

pub const updating_ucd = false;

pub const Field = struct {
    name: [:0]const u8,
    type: type,

    // For VarLen fields
    max_len: usize = 0,
    max_offset: usize = 0,
    embedded_len: usize = 0,

    pub const Runtime = struct {
        name: []const u8,
        type: []const u8,
        max_len: usize,
        max_offset: usize,
        embedded_len: usize,

        pub fn eql(a: Runtime, b: Runtime) bool {
            return a.max_len == b.max_len and
                a.max_offset == b.max_offset and
                a.embedded_len == b.embedded_len and
                std.mem.eql(u8, a.type, b.type) and
                std.mem.eql(u8, a.name, b.name);
        }

        pub fn write(self: Runtime, writer: anytype) !void {
            try writer.print(
                \\.{{
                \\    .name = "{s}",
                \\    .type = {s},
                \\    .max_len = {},
                \\    .max_offset = {},
                \\    .embedded_len = {},
                \\}},
                \\
            , .{
                self.name,
                self.type,
                self.max_len,
                self.max_offset,
                self.embedded_len,
            });
        }
    };

    pub fn runtime(self: Field, overrides: anytype) Runtime {
        var result: Runtime = .{
            .name = self.name,
            .type = @typeName(self.type),
            .max_len = self.max_len,
            .max_offset = self.max_offset,
            .embedded_len = self.embedded_len,
        };

        inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
            @field(result, f.name) = @field(overrides, f.name);
        }

        return result;
    }

    pub fn isVarLen(self: Field) bool {
        return @typeInfo(self.type) == .pointer;
    }

    pub fn override(self: Field, overrides: anytype) Field {
        var result = self;

        inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
            @field(result, f.name) = @field(overrides, f.name);
        }

        return result;
    }
};

pub const Table = struct {
    stages: Stages,
    fields: []const Field,
    //extensions: []const Extension,

    pub const Stages = union(enum) {
        // TODO: support two stage tables (and actually support auto)
        auto: void,
        //two: void,
        //three: void,

        len: Len,

        pub const Len = struct {
            stage1: usize,
            stage2: usize,
            data: usize,
        };
    };

    pub fn hasField(self: *const Table, name: []const u8) bool {
        return for (self.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                break true;
            }
        } else false;
    }

    pub fn field(self: *const Table, name: []const u8) Field {
        return for (self.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                break f;
            }
        } else @compileError("Field '" ++ name ++ "' not found in Table");
    }
};

//pub const Extension = struct {
//    fields: []const Field,
//    input_fields: []const []const u8,
//    compute: *const fn (cp: u21, input_data: anytype, source_data: anytype) void,
//
//    pub const Field = struct {
//        name: []const u8,
//        type_info: std.builtin.TypeInfo,
//    };
//
//    pub fn field(self: *const Table, name: []const u8) Field {
//        return for (self.fields.slice()) |f| {
//          if (std.mem.eql(u8, f.name(), name)) {
//                break f;
//            }
//        } else std.debug.panic("Field '{s}' not found in Table", .{name});
//    }
//};

pub const default = Table{
    .stages = .auto,
    .fields = &.{
        // UnicodeData fields
        .{
            .name = "name",
            .type = []const u8,
            .max_len = 88,
            .max_offset = 1031029,
            .embedded_len = 2,
        },
        .{ .name = "general_category", .type = types.GeneralCategory },
        .{ .name = "canonical_combining_class", .type = u8 },
        .{ .name = "bidi_class", .type = types.BidiClass },
        .{ .name = "decomposition_type", .type = types.DecompositionType },
        .{
            .name = "decomposition_mapping",
            .type = []const u21,
            .max_len = 18,
            .max_offset = 6454,
            .embedded_len = 0,
        },
        .{ .name = "numeric_type", .type = types.NumericType },
        .{ .name = "numeric_value_decimal", .type = ?u4 },
        .{ .name = "numeric_value_digit", .type = ?u4 },
        .{
            .name = "numeric_value_numeric",
            .type = []const u8,
            .max_len = 13,
            .max_offset = 503,
            .embedded_len = 1,
        },
        .{ .name = "is_bidi_mirrored", .type = bool },
        .{
            .name = "unicode_1_name",
            .type = []const u8,
            .max_len = 55,
            .max_offset = 49956,
            .embedded_len = 0,
        },
        .{ .name = "simple_uppercase_mapping", .type = ?u21 },
        .{ .name = "simple_lowercase_mapping", .type = ?u21 },
        .{ .name = "simple_titlecase_mapping", .type = ?u21 },

        // CaseFolding fields
        .{ .name = "case_folding_simple", .type = ?u21 },
        .{ .name = "case_folding_turkish", .type = ?u21 },
        .{
            .name = "case_folding_full",
            .type = []const u21,
            .max_len = 3,
            .max_offset = 160,
            .embedded_len = 0,
        },

        // DerivedCoreProperties fields
        .{ .name = "is_math", .type = bool },
        .{ .name = "is_alphabetic", .type = bool },
        .{ .name = "is_lowercase", .type = bool },
        .{ .name = "is_uppercase", .type = bool },
        .{ .name = "is_cased", .type = bool },
        .{ .name = "is_case_ignorable", .type = bool },
        .{ .name = "changes_when_lowercased", .type = bool },
        .{ .name = "changes_when_uppercased", .type = bool },
        .{ .name = "changes_when_titlecased", .type = bool },
        .{ .name = "changes_when_casefolded", .type = bool },
        .{ .name = "changes_when_casemapped", .type = bool },
        .{ .name = "is_id_start", .type = bool },
        .{ .name = "is_id_continue", .type = bool },
        .{ .name = "is_xid_start", .type = bool },
        .{ .name = "is_xid_continue", .type = bool },
        .{ .name = "is_default_ignorable_code_point", .type = bool },
        .{ .name = "is_grapheme_extend", .type = bool },
        .{ .name = "is_grapheme_base", .type = bool },
        .{ .name = "is_grapheme_link", .type = bool },
        .{ .name = "indic_conjunct_break", .type = types.IndicConjunctBreak },

        // EastAsianWidth field
        .{ .name = "east_asian_width", .type = types.EastAsianWidth },

        // OriginalGraphemeBreak field
        // The original field from GraphemeBreakProperty.txt, but without
        // treating emoji modifiers correctly, fixed below in GraphemeBreak.
        .{ .name = "original_grapheme_break", .type = types.OriginalGraphemeBreak },

        // EmojiData fields
        .{ .name = "is_emoji", .type = bool },
        .{ .name = "has_emoji_presentation", .type = bool },
        .{ .name = "is_emoji_modifier", .type = bool },
        .{ .name = "is_emoji_modifier_base", .type = bool },
        .{ .name = "is_emoji_component", .type = bool },
        .{ .name = "is_extended_pictographic", .type = bool },

        // GraphemeBreak field (derived)
        .{ .name = "grapheme_break", .type = types.GraphemeBreak },
    },
};

const updating_ucd_fields = brk: {
    var fields: [default.fields.len]Field = undefined;

    const offset_len_fields = [_]Field{
        default.field("name").override(.{
            .max_len = 200,
            .max_offset = 2_000_000,
        }),
        default.field("decomposition_mapping").override(.{
            .max_len = 40,
            .max_offset = 16_000,
        }),
        default.field("numeric_value_numeric").override(.{
            .max_len = 30,
            .max_offset = 4000,
        }),
        default.field("unicode_1_name").override(.{
            .max_len = 120,
            .max_offset = 100_000,
        }),
        default.field("case_folding_full").override(.{
            .max_len = 9,
            .max_offset = 500,
        }),
    };

    for (offset_len_fields, 0..) |f, i| {
        fields[i] = f.override(.{
            .embedded_len = 0,
        });
    }

    var i = offset_len_fields.len;

    for (default.fields) |f| {
        if (!f.isVarLen()) {
            fields[i] = f;
            i += 1;
        }
    }

    break :brk fields;
};

pub const updating_ucd_config = Table{
    .stages = .auto,
    .fields = &updating_ucd_fields,
};
