const std = @import("std");
const types = @import("types.zig");

pub const max_code_point: u21 = 0x10FFFF;
pub const code_point_range_end: u21 = max_code_point + 1;

pub const is_updating_ucd = false;

pub const Field = struct {
    name: [:0]const u8,
    type: type,

    // For Shift fields
    max_shift_down: u21 = 0,
    max_shift_up: u21 = 0,

    // For VarLen fields
    max_len: usize = 0,
    max_offset: usize = 0,
    embedded_len: usize = 0,

    pub const Runtime = struct {
        name: []const u8,
        type: []const u8,
        max_shift_down: u21,
        max_shift_up: u21,
        max_len: usize,
        max_offset: usize,
        embedded_len: usize,

        pub fn eql(a: Runtime, b: Runtime) bool {
            return a.max_shift_down == b.max_shift_down and
                a.max_shift_up == b.max_shift_up and
                a.max_len == b.max_len and
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
                \\
            , .{ self.name, self.type });
            if (self.max_shift_down != 0 or self.max_shift_up != 0) {
                try writer.print(
                    \\    .max_shift_down = {},
                    \\    .max_shift_up = {},
                    \\
                , .{ self.max_shift_down, self.max_shift_up });
            }
            if (self.max_len != 0) {
                try writer.print(
                    \\    .max_len = {},
                    \\    .max_offset = {},
                    \\    .embedded_len = {},
                    \\
                , .{ self.max_len, self.max_offset, self.embedded_len });
            }

            try writer.writeAll(
                \\},
                \\
            );
        }
    };

    pub const Kind = enum {
        basic,
        var_len,
        shift,
        optional,
    };

    pub fn kind(self: Field) Kind {
        switch (@typeInfo(self.type)) {
            .pointer => return .var_len,
            .optional => |o| {
                if (o.child == u21) {
                    return .shift;
                } else {
                    return .optional;
                }
            },
            else => {
                if (self.type == u21) {
                    return .shift;
                } else {
                    return .basic;
                }
            },
        }
    }

    pub fn extension(name: [:0]const u8, comptime T: type) Field {
        return .{
            .name = name,
            .type = T,
        };
    }

    pub fn runtime(self: Field, overrides: anytype) Runtime {
        var result: Runtime = .{
            .name = self.name,
            .type = @typeName(self.type),
            .max_shift_down = self.max_shift_down,
            .max_shift_up = self.max_shift_up,
            .max_len = self.max_len,
            .max_offset = self.max_offset,
            .embedded_len = self.embedded_len,
        };

        inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
            @field(result, f.name) = @field(overrides, f.name);
        }

        return result;
    }

    pub fn eql(a: Field, b: Field) bool {
        // Use runtime `eql` just to be lazy
        return a.runtime(.{}).eql(b.runtime(.{}));
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
    name: ?[]const u8 = null,
    stages: Stages = .auto,
    extensions: []const Extension = &.{},
    fields: []const Field,

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

    pub fn field(comptime self: *const Table, name: []const u8) Field {
        return for (self.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                break f;
            }
        } else @compileError("Field '" ++ name ++ "' not found in Table");
    }
};

pub const Extension = struct {
    inputs: []const [:0]const u8,
    fields: []const Field,
    compute: *const fn (cp: u21, data: anytype) void,

    pub fn field(comptime self: *const Extension, name: []const u8) Field {
        return for (self.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                break f;
            }
        } else @compileError("Field '" ++ name ++ "' not found in Extension");
    }
};

pub const default = Table{
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
        .{
            .name = "simple_uppercase_mapping",
            .type = ?u21,
            .max_shift_down = 38864,
            .max_shift_up = 42561,
        },
        .{
            .name = "simple_lowercase_mapping",
            .type = ?u21,
            .max_shift_down = 42561,
            .max_shift_up = 38864,
        },
        .{
            .name = "simple_titlecase_mapping",
            .type = ?u21,
            .max_shift_down = 38864,
            .max_shift_up = 42561,
        },

        // CaseFolding fields
        .{
            .name = "case_folding_simple",
            .type = u21,
            .max_shift_down = 42561,
            .max_shift_up = 35267,
        },
        .{
            .name = "case_folding_turkish",
            .type = u21,
            .max_shift_down = 199,
            .max_shift_up = 232,
        },
        .{
            .name = "case_folding_full",
            .type = []const u21,
            .max_len = 3,
            .max_offset = 160,
            .embedded_len = 0,
        },

        // SpecialCasing fields
        .{
            .name = "special_lowercase_mapping",
            .type = []const u21,
            .max_len = 3,
            .max_offset = 94,
            .embedded_len = 0,
        },
        .{
            .name = "special_titlecase_mapping",
            .type = []const u21,
            .max_len = 3,
            .max_offset = 140,
            .embedded_len = 0,
        },
        .{
            .name = "special_uppercase_mapping",
            .type = []const u21,
            .max_len = 3,
            .max_offset = 167,
            .embedded_len = 0,
        },
        .{
            .name = "special_casing_condition",
            .type = []const types.SpecialCasingCondition,
            .max_len = 2,
            .max_offset = 12,
            .embedded_len = 1,
        },

        // TODO:
        //.{
        //    .name = "full_lowercase_mapping",
        //    .type = []const u21,
        //    .max_len = 3,
        //    .max_offset = 94,
        //    .embedded_len = 0,
        //},

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

        // Block field
        .{ .name = "block", .type = types.Block },
    },
};

const updating_ucd_fields = brk: {
    var fields: [default.fields.len]Field = undefined;

    const var_len_or_shift_fields = [_]Field{
        // VarLen
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
        default.field("special_lowercase_mapping").override(.{
            .max_len = 9,
            .max_offset = 1000,
        }),
        default.field("special_titlecase_mapping").override(.{
            .max_len = 9,
            .max_offset = 1000,
        }),
        default.field("special_uppercase_mapping").override(.{
            .max_len = 9,
            .max_offset = 1000,
        }),
        default.field("special_casing_condition").override(.{
            .max_len = 9,
            .max_offset = 500,
        }),

        // Shift
        default.field("simple_uppercase_mapping").override(.{
            .max_shift_down = max_code_point,
            .max_shift_up = max_code_point,
        }),
        default.field("simple_lowercase_mapping").override(.{
            .max_shift_down = max_code_point,
            .max_shift_up = max_code_point,
        }),
        default.field("simple_titlecase_mapping").override(.{
            .max_shift_down = max_code_point,
            .max_shift_up = max_code_point,
        }),
        default.field("case_folding_simple").override(.{
            .max_shift_down = max_code_point,
            .max_shift_up = max_code_point,
        }),
        default.field("case_folding_turkish").override(.{
            .max_shift_down = max_code_point,
            .max_shift_up = max_code_point,
        }),
    };

    for (var_len_or_shift_fields, 0..) |f, i| {
        fields[i] = f.override(.{
            .embedded_len = 0,
        });
    }

    var i = var_len_or_shift_fields.len;

    for (default.fields) |f| {
        switch (f.kind()) {
            .basic, .optional => {
                fields[i] = f;
                i += 1;
            },
            else => {},
        }
    }

    break :brk fields;
};

pub const updating_ucd = Table{
    .fields = &updating_ucd_fields,
};
