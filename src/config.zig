const std = @import("std");
const types = @import("types.zig");

pub const max_code_point: u21 = 0x10FFFF;
pub const code_point_range_end: u21 = max_code_point + 1;

pub const default = Table{
    .fields = &.{
        // UnicodeData fields
        .{
            .name = "name",
            .type = []const u8,
            .max_len = 88,
            .max_offset = 1030461,
            .embedded_len = 2,
        },
        .{ .name = "general_category", .type = types.GeneralCategory },
        .{ .name = "canonical_combining_class", .type = u8 },
        .{ .name = "unicode_data_bidi_class", .type = types.BidiClass },
        .{ .name = "decomposition_type", .type = types.DecompositionType },
        .{
            .name = "decomposition_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = -181519,
            .shift_high = 99324,
            .max_len = 18,
            .max_offset = 4602,
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
            .cp_packing = .shift,
            .shift_low = -38864,
            .shift_high = 42561,
        },
        .{
            .name = "simple_lowercase_mapping",
            .type = ?u21,
            .cp_packing = .shift,
            .shift_low = -42561,
            .shift_high = 38864,
        },
        .{
            .name = "simple_titlecase_mapping",
            .type = ?u21,
            .cp_packing = .shift,
            .shift_low = -38864,
            .shift_high = 42561,
        },

        // CaseFolding fields
        .{
            .name = "case_folding_simple",
            .type = u21,
            .cp_packing = .shift,
            .shift_low = -42561,
            .shift_high = 35267,
        },
        .{
            .name = "case_folding_full",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = -42561,
            .shift_high = 35267,
            .max_len = 3,
            .max_offset = 160,
            .embedded_len = 0,
        },
        .{
            .name = "case_folding_turkish_only",
            .type = []const u21,
            .cp_packing = .direct,
            .shift_low = -199,
            .shift_high = 232,
            .max_len = 1,
            .max_offset = 2,
            .embedded_len = 0,
        },
        .{
            .name = "case_folding_common_only",
            .type = []const u21,
            .cp_packing = .direct,
            .shift_low = -42561,
            .shift_high = 35267,
            .max_len = 1,
            .max_offset = 1423,
            .embedded_len = 0,
        },
        .{
            .name = "case_folding_simple_only",
            .type = []const u21,
            .cp_packing = .direct,
            .shift_low = -7615,
            .shift_high = 1,
            .max_len = 1,
            .max_offset = 31,
            .embedded_len = 0,
        },
        .{
            .name = "case_folding_full_only",
            .type = []const u21,
            .max_len = 3,
            .max_offset = 160,
            .embedded_len = 0,
        },

        // SpecialCasing fields
        .{
            .name = "special_lowercase_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = -199,
            .shift_high = 232,
            .max_len = 3,
            .max_offset = 13,
            .embedded_len = 0,
        },
        .{
            .name = "special_titlecase_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = 0,
            .shift_high = 199,
            .max_len = 3,
            .max_offset = 104,
            .embedded_len = 0,
        },
        .{
            .name = "special_uppercase_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = 0,
            .shift_high = 199,
            .max_len = 3,
            .max_offset = 158,
            .embedded_len = 0,
        },
        .{
            .name = "special_casing_condition",
            .type = []const types.SpecialCasingCondition,
            .max_len = 2,
            .max_offset = 9,
            .embedded_len = 0,
        },

        //// Case mappings
        .{
            .name = "lowercase_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = -42561,
            .shift_high = 38864,
            .max_len = 1,
            .max_offset = 0,
            .embedded_len = 0,
        },
        .{
            .name = "titlecase_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = -38864,
            .shift_high = 42561,
            .max_len = 3,
            .max_offset = 104,
            .embedded_len = 0,
        },
        .{
            .name = "uppercase_mapping",
            .type = []const u21,
            .cp_packing = .shift_single_item,
            .shift_low = -38864,
            .shift_high = 42561,
            .max_len = 3,
            .max_offset = 158,
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
        .{ .name = "is_emoji_presentation", .type = bool },
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

pub const is_updating_ucd = false;

pub const Field = struct {
    name: [:0]const u8,
    type: type,

    // For Shift + VarLen fields
    cp_packing: CpPacking = .direct,
    shift_low: isize = 0,
    shift_high: isize = 0,

    // For VarLen fields
    max_len: usize = 0,
    max_offset: usize = 0,
    embedded_len: usize = 0,

    pub const CpPacking = enum {
        direct,
        shift, // Shift only
        shift_single_item, // VarLen only
    };

    pub const Runtime = struct {
        name: []const u8,
        type: []const u8,
        cp_packing: CpPacking,
        shift_low: isize,
        shift_high: isize,
        max_len: usize,
        max_offset: usize,
        embedded_len: usize,

        pub fn eql(a: Runtime, b: Runtime) bool {
            return a.cp_packing == b.cp_packing and
                a.shift_low == b.shift_low and
                a.shift_high == b.shift_high and
                a.max_len == b.max_len and
                a.max_offset == b.max_offset and
                a.embedded_len == b.embedded_len and
                std.mem.eql(u8, a.type, b.type) and
                std.mem.eql(u8, a.name, b.name);
        }

        pub fn override(self: Runtime, overrides: anytype) Runtime {
            var result: Runtime = .{
                .name = self.name,
                .type = self.type,
                .cp_packing = self.cp_packing,
                .shift_low = self.shift_low,
                .shift_high = self.shift_high,
                .max_len = self.max_len,
                .max_offset = self.max_offset,
                .embedded_len = self.embedded_len,
            };

            inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
                @field(result, f.name) = @field(overrides, f.name);
            }

            return result;
        }

        pub fn compareActual(self: Runtime, actual: Runtime) bool {
            var is_okay = true;

            if (self.shift_low != actual.shift_low) {
                std.log.err("Config for field '{s}' does not match actual. Set .shift_low = {d}, // change from {d}", .{ self.name, actual.shift_low, self.shift_low });
                is_okay = false;
            }

            if (self.shift_high != actual.shift_high) {
                std.log.err("Config for field '{s}' does not match actual. Set .shift_high = {d}, // change from {d}", .{ self.name, actual.shift_high, self.shift_high });
                is_okay = false;
            }

            if (self.max_len != actual.max_len) {
                std.log.err("Config for field '{s}' does not match actual. Set .max_len = {d}, // change from {d}", .{ self.name, actual.max_len, self.max_len });
                is_okay = false;
            }

            if (self.max_offset != actual.max_offset) {
                std.log.err("Config for field '{s}' does not match actual. Set .max_offset = {d}, // change from {d}", .{ self.name, actual.max_offset, self.max_offset });
                is_okay = false;
            }

            return is_okay;
        }

        pub fn write(self: Runtime, writer: anytype) !void {
            try writer.print(
                \\.{{
                \\    .name = "{s}",
                \\
            , .{self.name});

            var type_parts = std.mem.splitScalar(u8, self.type, '.');
            const base_type = type_parts.next().?;
            const rest_type = type_parts.rest();

            if (std.mem.endsWith(u8, base_type, "types") or
                std.mem.endsWith(u8, base_type, "types_x") or
                rest_type.len == 0)
            {
                try writer.print(
                    \\    .type = {s},
                    \\
                , .{self.type});
            } else {
                try writer.print(
                    \\    .type = build_config.{s},
                    \\
                , .{rest_type});
            }

            if (self.cp_packing != .direct or
                self.shift_low != 0 or
                self.shift_high != 0)
            {
                try writer.print(
                    \\    .cp_packing = .{s},
                    \\    .shift_low = {},
                    \\    .shift_high = {},
                    \\
                , .{ @tagName(self.cp_packing), self.shift_low, self.shift_high });
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
            .optional => {
                switch (self.cp_packing) {
                    .direct => return .optional,
                    .shift => return .shift,
                    else => @compileError("Optional field with invalid cp_packing: must be .direct or .shift"),
                }
            },
            else => {
                switch (self.cp_packing) {
                    .direct => return .basic,
                    .shift => return .shift,
                    else => @compileError("Non-optional field with invalid cp_packing: must be .direct or .shift"),
                }
            },
        }
    }

    pub fn runtime(self: Field) Runtime {
        return .{
            .name = self.name,
            .type = @typeName(self.type),
            .cp_packing = self.cp_packing,
            .shift_low = self.shift_low,
            .shift_high = self.shift_high,
            .max_len = self.max_len,
            .max_offset = self.max_offset,
            .embedded_len = self.embedded_len,
        };
    }

    pub fn eql(a: Field, b: Field) bool {
        // Use runtime `eql` just to be lazy
        return a.runtime().eql(b.runtime());
    }

    pub fn override(self: Field, overrides: anytype) Field {
        var result = self;

        inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
            if (!is_updating_ucd and (std.mem.eql(u8, f.name, "name") or
                std.mem.eql(u8, f.name, "type") or
                std.mem.eql(u8, f.name, "shift_low") or
                std.mem.eql(u8, f.name, "shift_high") or
                std.mem.eql(u8, f.name, "max_len")))
            {
                @compileError("Cannot override field '" ++ f.name ++ "'");
            } else if (std.mem.eql(u8, f.name, "cp_packing")) {
                switch (self.cp_packing) {
                    .shift => {
                        if (overrides.cp_packing == .shift_single_item) {
                            @panic("Cannot override shift with shift_single_item");
                        }
                    },
                    .shift_single_item => {
                        if (overrides.cp_packing == .shift) {
                            @panic("Cannot override shift_single_item with shift");
                        }
                    },
                    else => {},
                }
            }

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
        @setEvalBranchQuota(20_000);

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

    compute: *const fn (
        cp: u21,
        data: anytype,
        backing: anytype,
        tracking: anytype,
    ) void,

    pub fn field(comptime self: *const Extension, name: []const u8) Field {
        return for (self.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                break f;
            }
        } else @compileError("Field '" ++ name ++ "' not found in Extension");
    }
};
