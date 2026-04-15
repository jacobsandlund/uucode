const std = @import("std");
const config = @import("config.zig");

pub const log_level = .debug;

const EmojiOddOrEven = enum(u2) {
    not_emoji,
    even_emoji,
    odd_emoji,
};

const NextOrPrev = union(enum) {
    none: void,
    next: u21,
    prev: u21,
};

pub const fields = &config.mergeFields(config.fields, &.{
    .{ .name = "foo", .type = u8 },
    .{ .name = "bar_unused", .type = u8 },
    .{ .name = "emoji_odd_or_even", .type = EmojiOddOrEven },
    .{
        .name = "uppercase_mapping_first_char",
        .type = u21,
        .cp_packing = .shift,
        .shift_low = -64190,
        .shift_high = 42561,
    },
    .{ .name = "has_simple_lowercase", .type = bool },
    .{
        .name = "numeric_value_numeric_reversed",
        .type = []const u8,
        .max_len = 13,
        .max_offset = 503,
        .embedded_len = 1,
    },
    .{
        .name = "opt_emoji_odd_or_even",
        .type = ?EmojiOddOrEven,
        .min_value = 0,
        .max_value = 2,
    },
    .{
        .name = "next_or_prev",
        .type = NextOrPrev,
        .cp_packing = .shift,
        .shift_low = -1,
        .shift_high = 1,
    },
    .{
        .name = "next_or_prev_direct",
        .type = NextOrPrev,
    },
    .{
        .name = "bidi_paired_bracket_direct",
        .type = config.types.BidiPairedBracket,
    },
    .{
        .name = "maybe_bit",
        .type = ?bool,
        .min_value = 0,
        .max_value = 1,
    },
    .{
        .name = "canonical_decomposition_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .max_len = 2,
        .max_offset = 2092,
        .shift_low = -181519,
        .shift_high = 99324,
    },
});

pub const build_components = &config.mergeComponents(config.build_components, &.{
    .{
        .Impl = Foo,
        .inputs = &.{"original_grapheme_break"},
        .fields = &.{ "foo", "bar_unused" },
    },
    .{
        .Impl = EmojiOddOrEvenComponent,
        .inputs = &.{"is_emoji"},
        .fields = &.{"emoji_odd_or_even"},
    },
    .{
        .Impl = Info,
        .inputs = &.{
            "uppercase_mapping",
            "numeric_value_numeric",
            "numeric_value_decimal",
            "simple_lowercase_mapping",
        },
        .fields = &.{
            "uppercase_mapping_first_char",
            "has_simple_lowercase",
            "numeric_value_numeric_reversed",
        },
    },
    .{
        .Impl = OptEmojiOddOrEven,
        .inputs = &.{"emoji_odd_or_even"},
        .fields = &.{"opt_emoji_odd_or_even"},
    },
    .{
        .Impl = NextOrPrevComponent,
        .fields = &.{"next_or_prev"},
    },
    .{
        .Impl = NextOrPrevDirect,
        .inputs = &.{"next_or_prev"},
        .fields = &.{"next_or_prev_direct"},
    },
    .{
        .Impl = BidiPairedBracketDirect,
        .inputs = &.{"bidi_paired_bracket"},
        .fields = &.{"bidi_paired_bracket_direct"},
    },
    .{
        .Impl = MaybeBit,
        .fields = &.{"maybe_bit"},
    },
    .{
        .Impl = CanonicalDecomposition,
        .inputs = &.{ "decomposition_type", "decomposition_mapping" },
        .fields = &.{"canonical_decomposition_mapping"},
    },
});

pub const get_components = config.get_components;

pub const tables: []const config.Table = &.{
    .{
        .fields = &.{
            "foo",
            "emoji_odd_or_even",
            "uppercase_mapping_first_char",
            "has_simple_lowercase",
            "numeric_value_numeric_reversed",
            "next_or_prev",
            "next_or_prev_direct",
            "bidi_paired_bracket_direct",
            "name",
            "grapheme_break",
            "special_lowercase_mapping",
            "canonical_decomposition_mapping",
            "decomposition_type",
            "decomposition_mapping",
        },
    },
    .{
        .stages = .two,
        .fields = &.{
            "general_category",
            "case_folding_simple",
        },
    },
    .{
        .name = "pack",
        .packing = .@"packed",
        .fields = &.{
            "opt_emoji_odd_or_even",
            "maybe_bit",
            "bidi_paired_bracket",
        },
    },
    .{
        .name = "checks",
        .fields = &.{
            "simple_uppercase_mapping",
            "is_alphabetic",
            "is_lowercase",
            "is_uppercase",
            "is_emoji_vs_base",
            "is_emoji_modifier_base",
            "is_composition_exclusion",
            "is_bidi_mirrored",
            "is_math",
            "is_cased",
            "is_case_ignorable",
            "changes_when_lowercased",
            "changes_when_uppercased",
            "changes_when_titlecased",
            "changes_when_casefolded",
            "changes_when_casemapped",
            "is_id_start",
            "is_id_continue",
            "is_xid_start",
            "is_xid_continue",
            "is_default_ignorable",
            "is_grapheme_extend",
            "is_grapheme_base",
            "is_grapheme_link",
            "is_emoji",
            "is_emoji_presentation",
            "is_emoji_modifier",
            "is_emoji_component",
            "is_extended_pictographic",
        },
    },
    .{
        .name = "misc",
        .fields = &.{
            "joining_type",
            "joining_group",
            "east_asian_width",
            "canonical_combining_class",
            "numeric_type",
            "numeric_value_decimal",
            "numeric_value_digit",
            "simple_titlecase_mapping",
            "simple_lowercase_mapping",
            "original_grapheme_break",
            "indic_conjunct_break",
            "indic_positional_category",
            "indic_syllabic_category",
            "bidi_mirroring",
        },
    },
    .{
        .name = "case",
        .fields = &.{
            "unicode_1_name",
            "has_special_casing",
            "case_folding_full",
            "case_folding_turkish_only",
            "case_folding_common_only",
            "case_folding_simple_only",
            "case_folding_full_only",
            "special_titlecase_mapping",
            "special_uppercase_mapping",
            "special_lowercase_mapping_conditional",
            "special_titlecase_mapping_conditional",
            "special_uppercase_mapping_conditional",
            "uppercase_mapping",
            "lowercase_mapping",
            "titlecase_mapping",
        },
    },
    .{
        .name = "needed_for_tests",
        .fields = &.{
            "special_casing_condition",
            "bidi_class",
            "block",
            "script",
        },
    },
    .{
        .name = "wcwidth",
        .fields = &.{
            "grapheme_break_no_control",
            "wcwidth_standalone",
            "wcwidth_zero_in_grapheme",
        },
    },
};

const initField = config.initField;
const initAllocField = config.initAllocField;
const setBuiltField = config.setBuiltField;
const setField = config.setField;
const setAllocField = config.setAllocField;

const Foo = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = backing;
        _ = tracking;

        for (0..config.num_code_points) |i| {
            const input = inputs.get(i);
            var row: Row = undefined;
            setBuiltField(&row, "foo", switch (input.original_grapheme_break) {
                .other => @as(u8, 0),
                .control => @as(u8, 3),
                else => @as(u8, 10),
            });
            setBuiltField(&row, "bar_unused", switch (input.original_grapheme_break) {
                .other => @as(u8, 0),
                .prepend => @as(u8, 1),
                .extend => @as(u8, 4),
                else => @as(u8, 255),
            });
            rows.append(row);
        }
    }
};

const EmojiOddOrEvenComponent = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.emoji_odd_or_even);
        const input_items = inputs.items(.is_emoji);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            items[i] = if (!input_items[i])
                EmojiOddOrEven.not_emoji
            else if (cp % 2 == 0)
                EmojiOddOrEven.even_emoji
            else
                EmojiOddOrEven.odd_emoji;
        }
    }
};

const Info = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = io;
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            var row: Row = undefined;

            var single_item_buffer: [1]u21 = undefined;
            setField(
                &row,
                "uppercase_mapping_first_char",
                cp,
                input.uppercase_mapping.valueWith(
                    backing.uppercase_mapping,
                    &single_item_buffer,
                    cp,
                )[0],
                tracking,
            );

            setBuiltField(&row, "has_simple_lowercase", input.simple_lowercase_mapping.unshift(cp) != cp);

            var buffer: [13]u8 = undefined;
            for (input.numeric_value_numeric.value(backing.numeric_value_numeric), 0..) |digit, j| {
                buffer[input.numeric_value_numeric.len - j - 1] = digit;
            }

            try setAllocField(
                allocator,
                &row,
                "numeric_value_numeric_reversed",
                cp,
                buffer[0..input.numeric_value_numeric.len],
                tracking,
            );

            rows.append(row);
        }
    }
};

const OptEmojiOddOrEven = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = backing;

        rows.len = config.num_code_points;
        const items = rows.items(.opt_emoji_odd_or_even);
        const input_items = inputs.items(.emoji_odd_or_even);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            items[i] = initField(
                Row,
                "opt_emoji_odd_or_even",
                cp,
                @as(?EmojiOddOrEven, switch (input_items[i]) {
                    .even_emoji => .even_emoji,
                    .odd_emoji => .odd_emoji,
                    .not_emoji => null,
                }),
                tracking,
            );
        }
    }
};

const NextOrPrevComponent = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = inputs;
        _ = backing;

        rows.len = config.num_code_points;
        const items = rows.items(.next_or_prev);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            var nop: NextOrPrev = .none;
            if (0x1200 <= cp and cp <= 0x1235) {
                nop = switch (cp % 3) {
                    0 => .{ .next = cp + 1 },
                    1 => .{ .prev = cp - 1 },
                    2 => .none,
                    else => unreachable,
                };
            }
            items[i] = initField(Row, "next_or_prev", cp, nop, tracking);
        }
    }
};

const NextOrPrevDirect = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.next_or_prev_direct);
        const input_items = inputs.items(.next_or_prev);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            items[i] = input_items[i].unshift(cp);
        }
    }
};

const BidiPairedBracketDirect = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.bidi_paired_bracket_direct);
        const input_items = inputs.items(.bidi_paired_bracket);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            items[i] = input_items[i].unshift(cp);
        }
    }
};

const MaybeBit = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = allocator;
        _ = io;
        _ = inputs;
        _ = backing;

        rows.len = config.num_code_points;
        const items = rows.items(.maybe_bit);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            var maybe: ?bool = null;
            if (0x1200 <= cp and cp <= 0x1235) {
                maybe = cp % 2 == 0;
            }
            items[i] = initField(Row, "maybe_bit", cp, maybe, tracking);
        }
    }
};

const CanonicalDecomposition = struct {
    pub fn build(
        comptime InputRow: type,
        comptime Row: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        inputs: config.MultiSlice(InputRow),
        rows: *config.MultiSlice(Row),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = io;
        rows.len = config.num_code_points;
        const items = rows.items(.canonical_decomposition_mapping);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);

            var buffer: [1]u21 = undefined;
            const mapping = if (input.decomposition_type == .canonical)
                input.decomposition_mapping.valueWith(backing.decomposition_mapping, &buffer, cp)
            else
                &[_]u21{};

            items[i] = try initAllocField(
                Row,
                "canonical_decomposition_mapping",
                allocator,
                cp,
                mapping,
                tracking,
            );
        }
    }
};
