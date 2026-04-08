const std = @import("std");
const config = @import("config.zig");
const types = @import("types.zig");
const inlineAssert = config.quirks.inlineAssert;

const setBuiltField = config.setBuiltField;
const setField = config.setField;
const setAllocField = config.setAllocField;
const initField = config.initField;
const initAllocField = config.initAllocField;

pub const build_components: []const config.Component = &.{
    .{
        .Impl = UnicodeData,
        .fields = &.{
            "name",
            "general_category",
            "canonical_combining_class",
            "decomposition_type",
            "decomposition_mapping",
            "numeric_type",
            "numeric_value_decimal",
            "numeric_value_digit",
            "numeric_value_numeric",
            "is_bidi_mirrored",
            "unicode_1_name",
            "simple_uppercase_mapping",
            "simple_lowercase_mapping",
            "simple_titlecase_mapping",
        },
    },
    .{
        .Impl = CaseFolding,
        .fields = &.{
            "case_folding_turkish_only",
            "case_folding_common_only",
            "case_folding_simple_only",
            "case_folding_full_only",
        },
    },
    .{
        .Impl = SpecialCasing,
        .fields = &.{
            "has_special_casing",
            "special_lowercase_mapping",
            "special_titlecase_mapping",
            "special_uppercase_mapping",
            "special_casing_condition",
            "special_lowercase_mapping_conditional",
            "special_titlecase_mapping_conditional",
            "special_uppercase_mapping_conditional",
        },
    },
    .{
        .Impl = DerivedCoreProperties,
        .fields = &.{
            "is_math",
            "is_alphabetic",
            "is_lowercase",
            "is_uppercase",
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
            "indic_conjunct_break",
        },
    },
    .{ .Impl = DerivedBidiClass, .fields = &.{"bidi_class"} },
    .{ .Impl = EastAsianWidth, .fields = &.{"east_asian_width"} },
    .{ .Impl = GraphemeBreak, .fields = &.{"original_grapheme_break"} },
    .{
        .Impl = EmojiData,
        .fields = &.{
            "is_emoji",
            "is_emoji_presentation",
            "is_emoji_modifier",
            "is_emoji_modifier_base",
            "is_emoji_component",
            "is_extended_pictographic",
        },
    },
    .{ .Impl = EmojiVs, .fields = &.{"is_emoji_vs_base"} },
    .{ .Impl = BidiPairedBracket, .fields = &.{"bidi_paired_bracket"} },
    .{ .Impl = BidiMirroring, .fields = &.{"bidi_mirroring"} },
    .{ .Impl = Blocks, .fields = &.{"block"} },
    .{ .Impl = Scripts, .fields = &.{"script"} },
    .{ .Impl = JoiningType, .fields = &.{"joining_type"} },
    .{ .Impl = JoiningGroup, .fields = &.{"joining_group"} },
    .{ .Impl = CompositionExclusions, .fields = &.{"is_composition_exclusion"} },
    .{ .Impl = IndicPositionalCategory, .fields = &.{"indic_positional_category"} },
    .{ .Impl = IndicSyllabicCategory, .fields = &.{"indic_syllabic_category"} },
    .{
        .Impl = CaseFoldingSimple,
        .inputs = &.{
            "case_folding_simple_only",
            "case_folding_common_only",
            "case_folding_turkish_only",
        },
        .fields = &.{"case_folding_simple"},
    },
    .{
        .Impl = CaseFoldingFull,
        .inputs = &.{ "case_folding_full_only", "case_folding_common_only" },
        .fields = &.{"case_folding_full"},
    },
    .{
        .Impl = LowercaseMapping,
        .inputs = &.{
            "has_special_casing",
            "special_casing_condition",
            "special_lowercase_mapping",
            "simple_lowercase_mapping",
        },
        .fields = &.{"lowercase_mapping"},
    },
    .{
        .Impl = TitlecaseMapping,
        .inputs = &.{
            "has_special_casing",
            "special_casing_condition",
            "special_titlecase_mapping",
            "simple_titlecase_mapping",
        },
        .fields = &.{"titlecase_mapping"},
    },
    .{
        .Impl = UppercaseMapping,
        .inputs = &.{
            "has_special_casing",
            "special_casing_condition",
            "special_uppercase_mapping",
            "simple_uppercase_mapping",
        },
        .fields = &.{"uppercase_mapping"},
    },
    .{
        .Impl = GraphemeBreakDerived,
        .inputs = &.{
            "original_grapheme_break",
            "indic_conjunct_break",
            "is_emoji_modifier",
            "is_emoji_modifier_base",
            "is_extended_pictographic",
            "is_emoji_component",
        },
        .fields = &.{"grapheme_break"},
    },
    .{
        .Impl = GraphemeBreakNoControlComponent,
        .inputs = &.{"grapheme_break"},
        .fields = &.{"grapheme_break_no_control"},
    },
    .{
        .Impl = Wcwidth,
        .inputs = &.{
            "east_asian_width",
            "general_category",
            "grapheme_break",
            "is_default_ignorable",
            "is_emoji_modifier",
        },
        .fields = &.{
            "wcwidth_standalone",
            "wcwidth_zero_in_grapheme",
        },
    },
};

pub const get_components: []const config.Component = &.{};

pub fn parseCp(str: []const u8) !u21 {
    return std.fmt.parseInt(u21, str, 16);
}

test "parseCp" {
    try std.testing.expectEqual(0x0000, try parseCp("0000"));
    try std.testing.expectEqual(0x1F600, try parseCp("1F600"));
}

pub fn parseRange(str: []const u8) !struct { start: usize, end: usize } {
    if (std.mem.indexOf(u8, str, "..")) |dot_idx| {
        const start = try parseCp(str[0..dot_idx]);
        const end = try parseCp(str[dot_idx + 2 ..]);
        return .{ .start = start, .end = end + 1 };
    } else {
        const cp = try parseCp(str);
        return .{ .start = cp, .end = cp + 1 };
    }
}

test "parseRange" {
    const range = try parseRange("0030..0039");
    try std.testing.expectEqual(0x0030, range.start);
    try std.testing.expectEqual(0x003A, range.end);

    const single = try parseRange("1F600");
    try std.testing.expectEqual(0x1F600, single.start);
    try std.testing.expectEqual(0x1F601, single.end);
}

fn readFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    defer file.close(io);
    var buf: [2048]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    return try file_reader.interface.allocRemaining(allocator, .unlimited);
}

pub fn trim(line: []const u8) []const u8 {
    if (std.mem.indexOf(u8, line, "#")) |idx| {
        return std.mem.trim(u8, line[0..idx], " \t\r");
    }
    return std.mem.trim(u8, line, " \t\r");
}

const UnicodeData = struct {
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
        _ = inputs;
        _ = backing;

        var default_row: Row = comptime blk: {
            var row: Row = undefined;
            setBuiltField(&row, "name", .empty);
            setBuiltField(&row, "general_category", .other_not_assigned);
            setBuiltField(&row, "canonical_combining_class", 0);
            setBuiltField(&row, "decomposition_type", .default);
            setBuiltField(&row, "decomposition_mapping", .same);
            setBuiltField(&row, "numeric_type", .none);
            setBuiltField(&row, "numeric_value_numeric", .empty);
            setBuiltField(&row, "is_bidi_mirrored", false);
            setBuiltField(&row, "unicode_1_name", .empty);
            setBuiltField(&row, "simple_uppercase_mapping", .same);
            setBuiltField(&row, "simple_lowercase_mapping", .same);
            setBuiltField(&row, "simple_titlecase_mapping", .same);
            break :blk row;
        };
        setField(&default_row, "numeric_value_decimal", 0, null, tracking);
        setField(&default_row, "numeric_value_digit", 0, null, tracking);

        const file_path = "ucd/UnicodeData.txt";

        // TODO: look for defaults in the Derived Extracted properties files:
        // https://www.unicode.org/reports/tr44/#Derived_Extracted
        //
        // > For nondefault values of properties, if there is any inadvertent
        // mismatch between the primary data files specifying those properties and
        // these lists of extracted properties, the primary data files are taken as
        // definitive. However, for default values of properties, the extracted
        // data files are definitive.

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        var range_row: ?Row = null;
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = parts.next().?;
            const cp = try parseCp(cp_str);

            // Fill ranges or gaps
            while (rows.len < cp) {
                rows.append(range_row orelse default_row);
            }

            if (range_row != null) {
                // We're in a range, so the next entry marks the last, with the same
                // information.
                inlineAssert(std.mem.endsWith(u8, parts.next().?, "Last>"));
                rows.append(range_row.?);
                range_row = null;
                continue;
            }

            const name_str = parts.next().?; // Field 1
            const general_category_str = parts.next().?; // Field 2
            const canonical_combining_class = try std.fmt.parseInt(u8, parts.next().?, 10); // Field 3
            _ = parts.next().?; // Field 4: Bidi_Class (handled by DerivedBidiClass component)
            const decomposition_str = parts.next().?; // Field 5: Combined type and mapping
            const numeric_decimal_str = parts.next().?; // Field 6
            const numeric_digit_str = parts.next().?; // Field 7
            const numeric_value_numeric = parts.next().?; // Field 8
            const is_bidi_mirrored = std.mem.eql(u8, parts.next().?, "Y"); // Field 9
            const unicode_1_name = parts.next().?; // Field 10
            _ = parts.next().?; // Field 11: Obsolete ISO_Comment
            const simple_uppercase_mapping_str = parts.next().?; // Field 12
            const simple_lowercase_mapping_str = parts.next().?; // Field 13
            const simple_titlecase_mapping_str = parts.next().?; // Field 14

            const name = if (std.mem.endsWith(u8, name_str, "First>")) name_str["<".len..(name_str.len - ", First>".len)] else name_str;
            const general_category = general_category_map.get(general_category_str) orelse blk: {
                std.log.err("Unknown general category: {s}", .{general_category_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .other_not_assigned;
                }
            };

            const simple_uppercase_mapping = if (simple_uppercase_mapping_str.len == 0)
                cp
            else
                try parseCp(simple_uppercase_mapping_str);
            const simple_lowercase_mapping = if (simple_lowercase_mapping_str.len == 0)
                cp
            else
                try parseCp(simple_lowercase_mapping_str);
            const simple_titlecase_mapping = if (simple_titlecase_mapping_str.len == 0)
                simple_uppercase_mapping
            else
                try parseCp(simple_titlecase_mapping_str);

            // Parse decomposition type and mapping from single field
            var decomposition_type: types.DecompositionType = undefined;
            var decomposition_mapping: [40]u21 = undefined; // Max is currently 18
            var decomposition_mapping_len: usize = undefined;

            if (decomposition_str.len > 0) {
                decomposition_mapping_len = 0;

                // Non-empty field means canonical unless explicit type is given
                decomposition_type = types.DecompositionType.canonical;
                var mapping_str = decomposition_str;

                if (std.mem.startsWith(u8, decomposition_str, "<")) {
                    // Compatibility decomposition with type in angle brackets
                    const end_bracket = std.mem.indexOf(u8, decomposition_str, ">") orelse {
                        std.log.err("Invalid decomposition format: {s}", .{decomposition_str});
                        unreachable;
                    };
                    const type_str = decomposition_str[1..end_bracket];
                    decomposition_type = std.meta.stringToEnum(types.DecompositionType, type_str) orelse blk: {
                        std.log.err("Unknown decomposition type: {s}", .{type_str});
                        if (!config.is_updating_ucd) {
                            unreachable;
                        } else {
                            break :blk .canonical;
                        }
                    };
                    mapping_str = std.mem.trim(u8, decomposition_str[end_bracket + 1 ..], " \t\r");
                }

                // Parse code points from mapping string
                if (mapping_str.len > 0) {
                    var mapping_parts = std.mem.splitScalar(u8, mapping_str, ' ');

                    while (mapping_parts.next()) |part| {
                        if (part.len == 0) continue;
                        decomposition_mapping[decomposition_mapping_len] = try parseCp(part);
                        decomposition_mapping_len += 1;
                    }
                }
            } else {
                // Default: character decomposes to itself (field 5 empty)
                decomposition_type = .default;
                decomposition_mapping_len = 1;
                decomposition_mapping[0] = cp;
            }

            // Determine numeric type and parse values based on which field has a value
            var numeric_type = types.NumericType.none;
            var numeric_value_decimal: ?u4 = null;
            var numeric_value_digit: ?u4 = null;

            if (numeric_decimal_str.len > 0) {
                numeric_type = types.NumericType.decimal;
                numeric_value_decimal = std.fmt.parseInt(u4, numeric_decimal_str, 10) catch |err| {
                    std.log.err("Invalid decimal numeric value '{s}' at code point {X}: {}", .{ numeric_decimal_str, cp, err });
                    unreachable;
                };
            } else if (numeric_digit_str.len > 0) {
                numeric_type = types.NumericType.digit;
                numeric_value_digit = std.fmt.parseInt(u4, numeric_digit_str, 10) catch |err| {
                    std.log.err("Invalid digit numeric value '{s}' at code point {X}: {}", .{ numeric_digit_str, cp, err });
                    unreachable;
                };
            } else if (numeric_value_numeric.len > 0) {
                numeric_type = types.NumericType.numeric;
            }

            var row: Row = undefined;
            try setAllocField(
                allocator,
                &row,
                "name",
                cp,
                name,
                tracking,
            );
            try setAllocField(allocator, &row, "name", cp, name, tracking);
            setBuiltField(&row, "general_category", general_category);
            setBuiltField(&row, "canonical_combining_class", canonical_combining_class);
            setBuiltField(&row, "decomposition_type", decomposition_type);
            try setAllocField(
                allocator,
                &row,
                "decomposition_mapping",
                cp,
                decomposition_mapping[0..decomposition_mapping_len],
                tracking,
            );
            setBuiltField(&row, "numeric_type", numeric_type);
            setField(&row, "numeric_value_decimal", cp, numeric_value_decimal, tracking);
            setField(&row, "numeric_value_digit", cp, numeric_value_digit, tracking);
            try setAllocField(
                allocator,
                &row,
                "numeric_value_numeric",
                cp,
                numeric_value_numeric,
                tracking,
            );
            setBuiltField(&row, "is_bidi_mirrored", is_bidi_mirrored);
            try setAllocField(
                allocator,
                &row,
                "unicode_1_name",
                cp,
                unicode_1_name,
                tracking,
            );
            setField(&row, "simple_uppercase_mapping", cp, simple_uppercase_mapping, tracking);
            setField(&row, "simple_lowercase_mapping", cp, simple_lowercase_mapping, tracking);
            setField(&row, "simple_titlecase_mapping", cp, simple_titlecase_mapping, tracking);

            // Handle range entries with "First>" and "Last>"
            if (std.mem.endsWith(u8, name_str, "First>")) {
                range_row = row;
            }

            rows.append(row);
        }

        // Fill any remaining gaps at the end with default values
        for (rows.len..config.num_code_points) |_| {
            rows.append(default_row);
        }
    }
};

const general_category_map = std.StaticStringMap(types.GeneralCategory).initComptime(.{
    .{ "Lu", .letter_uppercase },
    .{ "Ll", .letter_lowercase },
    .{ "Lt", .letter_titlecase },
    .{ "Lm", .letter_modifier },
    .{ "Lo", .letter_other },
    .{ "Mn", .mark_nonspacing },
    .{ "Mc", .mark_spacing_combining },
    .{ "Me", .mark_enclosing },
    .{ "Nd", .number_decimal_digit },
    .{ "Nl", .number_letter },
    .{ "No", .number_other },
    .{ "Pc", .punctuation_connector },
    .{ "Pd", .punctuation_dash },
    .{ "Ps", .punctuation_open },
    .{ "Pe", .punctuation_close },
    .{ "Pi", .punctuation_initial_quote },
    .{ "Pf", .punctuation_final_quote },
    .{ "Po", .punctuation_other },
    .{ "Sm", .symbol_math },
    .{ "Sc", .symbol_currency },
    .{ "Sk", .symbol_modifier },
    .{ "So", .symbol_other },
    .{ "Zs", .separator_space },
    .{ "Zl", .separator_line },
    .{ "Zp", .separator_paragraph },
    .{ "Cc", .other_control },
    .{ "Cf", .other_format },
    .{ "Cs", .other_surrogate },
    .{ "Co", .other_private_use },
    .{ "Cn", .other_not_assigned },
});

const bidi_class_map = std.StaticStringMap(types.BidiClass).initComptime(.{
    .{ "L", .left_to_right },
    .{ "LRE", .left_to_right_embedding },
    .{ "LRO", .left_to_right_override },
    .{ "R", .right_to_left },
    .{ "AL", .right_to_left_arabic },
    .{ "RLE", .right_to_left_embedding },
    .{ "RLO", .right_to_left_override },
    .{ "PDF", .pop_directional_format },
    .{ "EN", .european_number },
    .{ "ES", .european_number_separator },
    .{ "ET", .european_number_terminator },
    .{ "AN", .arabic_number },
    .{ "CS", .common_number_separator },
    .{ "NSM", .nonspacing_mark },
    .{ "BN", .boundary_neutral },
    .{ "B", .paragraph_separator },
    .{ "S", .segment_separator },
    .{ "WS", .whitespace },
    .{ "ON", .other_neutrals },
    .{ "LRI", .left_to_right_isolate },
    .{ "RLI", .right_to_left_isolate },
    .{ "FSI", .first_strong_isolate },
    .{ "PDI", .pop_directional_isolate },
});

const CaseFolding = struct {
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
        _ = inputs;
        _ = backing;

        const default_row: Row = comptime blk: {
            var row: Row = undefined;
            setBuiltField(&row, "case_folding_turkish_only", .null);
            setBuiltField(&row, "case_folding_common_only", .null);
            setBuiltField(&row, "case_folding_simple_only", .null);
            setBuiltField(&row, "case_folding_full_only", .empty);
            break :blk row;
        };

        rows.len = config.num_code_points;
        rows.memset(default_row);

        const file_path = "ucd/CaseFolding.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const cp = try parseCp(cp_str);

            const status_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const status = if (status_str.len > 0) status_str[0] else 0;

            const mapping_str = std.mem.trim(u8, parts.next() orelse "", " \t\r");
            var mapping_parts = std.mem.splitScalar(u8, mapping_str, ' ');

            var mapping: [9]u21 = undefined;
            var mapping_len: u2 = 0;

            while (mapping_parts.next()) |part| {
                if (part.len == 0) continue;
                const mapped_cp = try parseCp(part);
                mapping[mapping_len] = mapped_cp;
                mapping_len += 1;
            }

            var row = rows.get(cp);
            switch (status) {
                'S' => {
                    inlineAssert(mapping_len == 1);
                    setField(&row, "case_folding_simple_only", cp, mapping[0], tracking);
                },
                'C' => {
                    inlineAssert(mapping_len == 1);
                    setField(&row, "case_folding_common_only", cp, mapping[0], tracking);
                },
                'T' => {
                    inlineAssert(mapping_len == 1);
                    setField(&row, "case_folding_turkish_only", cp, mapping[0], tracking);
                },
                'F' => {
                    inlineAssert(mapping_len > 1);
                    try setAllocField(
                        allocator,
                        &row,
                        "case_folding_full_only",
                        cp,
                        mapping[0..mapping_len],
                        tracking,
                    );
                },
                else => unreachable,
            }
            rows.set(cp, row);
        }
    }
};

const SpecialCasing = struct {
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
        _ = inputs;
        _ = backing;

        const default_row: Row = comptime blk: {
            var row: Row = undefined;
            setBuiltField(&row, "has_special_casing", false);
            setBuiltField(&row, "special_lowercase_mapping", .empty);
            setBuiltField(&row, "special_titlecase_mapping", .empty);
            setBuiltField(&row, "special_uppercase_mapping", .empty);
            setBuiltField(&row, "special_casing_condition", .empty);
            setBuiltField(&row, "special_lowercase_mapping_conditional", .empty);
            setBuiltField(&row, "special_titlecase_mapping_conditional", .empty);
            setBuiltField(&row, "special_uppercase_mapping_conditional", .empty);
            break :blk row;
        };

        rows.len = config.num_code_points;
        rows.memset(default_row);

        const file_path = "ucd/SpecialCasing.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const cp = try parseCp(cp_str);

            const lower_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const title_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const upper_str = std.mem.trim(u8, parts.next().?, " \t\r");

            var is_conditional = false;
            var conditions: [6]types.SpecialCasingCondition = undefined;
            var conditions_len: u8 = 0;
            if (parts.next()) |condition_str| {
                const trimmed_conditions = std.mem.trim(u8, condition_str, " \t\r");
                if (trimmed_conditions.len > 0) {
                    is_conditional = true;
                    var condition_parts = std.mem.splitScalar(u8, trimmed_conditions, ' ');
                    while (condition_parts.next()) |condition_part| {
                        const trimmed_condition = std.mem.trim(u8, condition_part, " \t\r");
                        if (trimmed_condition.len == 0) continue;
                        const condition = special_casing_condition_map.get(trimmed_condition) orelse blk: {
                            std.log.err("Unknown special casing condition '{s}'", .{trimmed_condition});
                            if (!config.is_updating_ucd) {
                                unreachable;
                            } else {
                                break :blk .final_sigma;
                            }
                        };
                        conditions[conditions_len] = condition;
                        conditions_len += 1;
                    }
                }
            }

            var row = rows.get(cp);

            var lower_mapping: [9]u21 = undefined;
            var lower_mapping_len: u8 = 0;
            var lower_parts = std.mem.splitScalar(u8, lower_str, ' ');
            while (lower_parts.next()) |part| {
                if (part.len == 0) continue;
                lower_mapping[lower_mapping_len] = try parseCp(part);
                lower_mapping_len += 1;
            }

            var title_mapping: [9]u21 = undefined;
            var title_mapping_len: u8 = 0;
            var title_parts = std.mem.splitScalar(u8, title_str, ' ');
            while (title_parts.next()) |part| {
                if (part.len == 0) continue;
                title_mapping[title_mapping_len] = try parseCp(part);
                title_mapping_len += 1;
            }

            var upper_mapping: [9]u21 = undefined;
            var upper_mapping_len: u8 = 0;
            var upper_parts = std.mem.splitScalar(u8, upper_str, ' ');
            while (upper_parts.next()) |part| {
                if (part.len == 0) continue;
                upper_mapping[upper_mapping_len] = try parseCp(part);
                upper_mapping_len += 1;
            }

            setBuiltField(&row, "has_special_casing", true);
            if (is_conditional) {
                try setAllocField(allocator, &row, "special_lowercase_mapping_conditional", cp, lower_mapping[0..lower_mapping_len], tracking);
                try setAllocField(allocator, &row, "special_titlecase_mapping_conditional", cp, title_mapping[0..title_mapping_len], tracking);
                try setAllocField(allocator, &row, "special_uppercase_mapping_conditional", cp, upper_mapping[0..upper_mapping_len], tracking);
                try setAllocField(allocator, &row, "special_casing_condition", cp, conditions[0..conditions_len], tracking);
            } else {
                try setAllocField(allocator, &row, "special_lowercase_mapping", cp, lower_mapping[0..lower_mapping_len], tracking);
                try setAllocField(allocator, &row, "special_titlecase_mapping", cp, title_mapping[0..title_mapping_len], tracking);
                try setAllocField(allocator, &row, "special_uppercase_mapping", cp, upper_mapping[0..upper_mapping_len], tracking);
            }
            rows.set(cp, row);
        }
    }
};

const special_casing_condition_map = std.StaticStringMap(types.SpecialCasingCondition).initComptime(.{
    .{ "Final_Sigma", .final_sigma },
    .{ "After_Soft_Dotted", .after_soft_dotted },
    .{ "More_Above", .more_above },
    .{ "After_I", .after_i },
    .{ "Not_Before_Dot", .not_before_dot },
    .{ "lt", .lt },
    .{ "tr", .tr },
    .{ "az", .az },
});

const DerivedCoreProperties = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        const default_row: Row = comptime blk: {
            var row: Row = undefined;
            setBuiltField(&row, "is_math", false);
            setBuiltField(&row, "is_alphabetic", false);
            setBuiltField(&row, "is_lowercase", false);
            setBuiltField(&row, "is_uppercase", false);
            setBuiltField(&row, "is_cased", false);
            setBuiltField(&row, "is_case_ignorable", false);
            setBuiltField(&row, "changes_when_lowercased", false);
            setBuiltField(&row, "changes_when_uppercased", false);
            setBuiltField(&row, "changes_when_titlecased", false);
            setBuiltField(&row, "changes_when_casefolded", false);
            setBuiltField(&row, "changes_when_casemapped", false);
            setBuiltField(&row, "is_id_start", false);
            setBuiltField(&row, "is_id_continue", false);
            setBuiltField(&row, "is_xid_start", false);
            setBuiltField(&row, "is_xid_continue", false);
            setBuiltField(&row, "is_default_ignorable", false);
            setBuiltField(&row, "is_grapheme_extend", false);
            setBuiltField(&row, "is_grapheme_base", false);
            setBuiltField(&row, "is_grapheme_link", false);
            setBuiltField(&row, "indic_conjunct_break", .none);
            break :blk row;
        };

        rows.len = config.num_code_points;
        rows.memset(default_row);

        const file_path = "ucd/DerivedCoreProperties.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const property_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const value_str = if (parts.next()) |v| std.mem.trim(u8, v, " \t\r") else "";

            const range = try parseRange(cp_str);
            const property = derived_core_property_map.get(property_str) orelse blk: {
                std.log.err("Unknown DerivedCoreProperties property: {s}", .{property_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .is_alphabetic;
                }
            };

            const indic_conjunct_break = indic_conjunct_break_map.get(value_str);

            for (range.start..range.end) |cp| {
                var row = rows.get(cp);
                switch (property) {
                    .indic_conjunct_break => {
                        setBuiltField(&row, "indic_conjunct_break", indic_conjunct_break orelse blk: {
                            std.log.err("Unknown InCB value: {s}", .{value_str});
                            if (!config.is_updating_ucd) {
                                unreachable;
                            } else {
                                break :blk .linker;
                            }
                        });
                    },
                    inline else => |p| {
                        setBuiltField(&row, @tagName(p), true);
                    },
                }
                rows.set(cp, row);
            }
        }
    }
};

const derived_core_property_map = std.StaticStringMap(enum {
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
    is_default_ignorable,
    is_grapheme_extend,
    is_grapheme_base,
    is_grapheme_link,
    indic_conjunct_break,
}).initComptime(.{
    .{ "Math", .is_math },
    .{ "Alphabetic", .is_alphabetic },
    .{ "Lowercase", .is_lowercase },
    .{ "Uppercase", .is_uppercase },
    .{ "Cased", .is_cased },
    .{ "Case_Ignorable", .is_case_ignorable },
    .{ "Changes_When_Lowercased", .changes_when_lowercased },
    .{ "Changes_When_Uppercased", .changes_when_uppercased },
    .{ "Changes_When_Titlecased", .changes_when_titlecased },
    .{ "Changes_When_Casefolded", .changes_when_casefolded },
    .{ "Changes_When_Casemapped", .changes_when_casemapped },
    .{ "ID_Start", .is_id_start },
    .{ "ID_Continue", .is_id_continue },
    .{ "XID_Start", .is_xid_start },
    .{ "XID_Continue", .is_xid_continue },
    .{ "Default_Ignorable_Code_Point", .is_default_ignorable },
    .{ "Grapheme_Extend", .is_grapheme_extend },
    .{ "Grapheme_Base", .is_grapheme_base },
    .{ "Grapheme_Link", .is_grapheme_link },
    .{ "InCB", .indic_conjunct_break },
});

const indic_conjunct_break_map = std.StaticStringMap(types.IndicConjunctBreak).initComptime(.{
    .{ "Linker", .linker },
    .{ "Consonant", .consonant },
    .{ "Extend", .extend },
});

const DerivedBidiClass = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.bidi_class);
        @memset(items, .left_to_right);

        const file_path = "ucd/extracted/DerivedBidiClass.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            if (std.mem.startsWith(u8, trimmed, "# @missing:")) {
                const missing_line = trimmed["# @missing:".len..];
                var parts = std.mem.splitScalar(u8, missing_line, ';');
                const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
                const class_str = std.mem.trim(u8, parts.next().?, " \t\r");

                const range = try parseRange(cp_str);

                if (std.mem.eql(u8, class_str, "Left_To_Right")) {
                    continue;
                }

                const bidi_class = bidi_longform_map.get(class_str) orelse blk: {
                    std.log.err("Unknown @missing BidiClass value: {s}", .{class_str});
                    if (!config.is_updating_ucd) {
                        unreachable;
                    } else {
                        break :blk .left_to_right;
                    }
                };

                for (range.start..range.end) |cp| {
                    items[cp] = bidi_class;
                }
                continue;
            }

            const data_line = trim(trimmed);
            if (data_line.len == 0) continue;

            var parts = std.mem.splitScalar(u8, data_line, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const class_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);

            const bidi_class = bidi_class_map.get(class_str) orelse blk: {
                std.log.err("Unknown BidiClass value: {s}", .{class_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .left_to_right;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = bidi_class;
            }
        }
    }
};

const bidi_longform_map = std.StaticStringMap(types.BidiClass).initComptime(.{
    .{ "Left_To_Right", .left_to_right },
    .{ "Right_To_Left", .right_to_left },
    .{ "Arabic_Letter", .right_to_left_arabic },
    .{ "European_Terminator", .european_number_terminator },
});

const EastAsianWidth = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.east_asian_width);
        @memset(items, .neutral);

        const file_path = "ucd/extracted/DerivedEastAsianWidth.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            if (std.mem.startsWith(u8, trimmed, "# @missing:")) {
                const missing_line = trimmed["# @missing:".len..];
                var parts = std.mem.splitScalar(u8, missing_line, ';');
                const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
                const width_str = std.mem.trim(u8, parts.next().?, " \t\r");

                const range = try parseRange(cp_str);

                if (std.mem.eql(u8, width_str, "Neutral")) {
                    continue;
                }

                if (!std.mem.eql(u8, width_str, "Wide")) {
                    std.log.err("Unknown @missing EastAsianWidth value: {s}", .{width_str});
                    if (!config.is_updating_ucd) {
                        unreachable;
                    }
                }

                for (range.start..range.end) |cp| {
                    items[cp] = .wide;
                }
                continue;
            }

            const data_line = trim(trimmed);
            if (data_line.len == 0) continue;

            var parts = std.mem.splitScalar(u8, data_line, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const width_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);

            const width = east_asian_width_map.get(width_str) orelse blk: {
                std.log.err("Unknown EastAsianWidth value: {s}", .{width_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .wide;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = width;
            }
        }
    }
};

const east_asian_width_map = std.StaticStringMap(types.EastAsianWidth).initComptime(.{
    .{ "F", .fullwidth },
    .{ "H", .halfwidth },
    .{ "W", .wide },
    .{ "Na", .narrow },
    .{ "A", .ambiguous },
    .{ "N", .neutral },
});

const GraphemeBreak = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.original_grapheme_break);
        @memset(items, .other);

        const file_path = "ucd/auxiliary/GraphemeBreakProperty.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const prop_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);

            const prop = grapheme_break_property_map.get(prop_str) orelse types.OriginalGraphemeBreak.other;

            for (range.start..range.end) |cp| {
                items[cp] = prop;
            }
        }
    }
};

const grapheme_break_property_map = std.StaticStringMap(types.OriginalGraphemeBreak).initComptime(.{
    .{ "Prepend", .prepend },
    .{ "CR", .cr },
    .{ "LF", .lf },
    .{ "Control", .control },
    .{ "Extend", .extend },
    .{ "Regional_Indicator", .regional_indicator },
    .{ "SpacingMark", .spacing_mark },
    .{ "L", .l },
    .{ "V", .v },
    .{ "T", .t },
    .{ "LV", .lv },
    .{ "LVT", .lvt },
    .{ "ZWJ", .zwj },
});

const EmojiData = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        const default_row: Row = comptime blk: {
            var row: Row = undefined;
            setBuiltField(&row, "is_emoji", false);
            setBuiltField(&row, "is_emoji_presentation", false);
            setBuiltField(&row, "is_emoji_modifier", false);
            setBuiltField(&row, "is_emoji_modifier_base", false);
            setBuiltField(&row, "is_emoji_component", false);
            setBuiltField(&row, "is_extended_pictographic", false);
            break :blk row;
        };

        rows.len = config.num_code_points;
        rows.memset(default_row);

        const file_path = "ucd/emoji/emoji-data.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const prop_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);

            for (range.start..range.end) |cp| {
                const property = emoji_data_property_map.get(prop_str) orelse blk: {
                    std.log.err("Unknown EmojiData property: {s}", .{prop_str});
                    if (!config.is_updating_ucd) {
                        unreachable;
                    } else {
                        break :blk .is_emoji;
                    }
                };

                var row = rows.get(cp);
                switch (property) {
                    inline else => |p| {
                        setBuiltField(&row, @tagName(p), true);
                    },
                }
                rows.set(cp, row);
            }
        }
    }
};

const emoji_data_property_map = std.StaticStringMap(enum {
    is_emoji,
    is_emoji_presentation,
    is_emoji_modifier,
    is_emoji_modifier_base,
    is_emoji_component,
    is_extended_pictographic,
}).initComptime(.{
    .{ "Emoji", .is_emoji },
    .{ "Emoji_Presentation", .is_emoji_presentation },
    .{ "Emoji_Modifier", .is_emoji_modifier },
    .{ "Emoji_Modifier_Base", .is_emoji_modifier_base },
    .{ "Emoji_Component", .is_emoji_component },
    .{ "Extended_Pictographic", .is_extended_pictographic },
});

const EmojiVs = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        const file_path = "ucd/emoji/emoji-variation-sequences.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        rows.len = config.num_code_points;
        const items = rows.items(.is_emoji_vs_base);
        @memset(items, false);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ' ');
            const cp = try parseCp(parts.next().?);
            const vs = try parseCp(parts.next().?);

            // This counts only "text style" lines, but see the comment
            // in src/config.zig: the "emoji style" lines are 1:1
            if (vs == 0xFE0E) {
                items[cp] = true;
            } else {
                inlineAssert(vs == 0xFE0F and items[cp]);
            }
        }
    }
};

const BidiPairedBracket = struct {
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
        _ = inputs;
        _ = backing;

        rows.len = config.num_code_points;
        const items = rows.items(.bidi_paired_bracket);
        @memset(items, initField(Row, "bidi_paired_bracket", 0, @as(types.BidiPairedBracket, .none), tracking));

        const file_path = "ucd/BidiBrackets.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const paired_cp_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const op = try parseCp(cp_str);
            const paired = try parseCp(paired_cp_str);

            const type_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const bracket_type: types.BidiPairedBracket = switch (type_str[0]) {
                'c' => .{ .close = paired },
                'o' => .{ .open = paired },
                else => unreachable,
            };

            items[op] = initField(Row, "bidi_paired_bracket", op, bracket_type, tracking);
        }
    }
};

const BidiMirroring = struct {
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
        _ = inputs;
        _ = backing;

        rows.len = config.num_code_points;
        const items = rows.items(.bidi_mirroring);
        @memset(items, initField(Row, "bidi_mirroring", 0, null, tracking));

        const file_path = "ucd/BidiMirroring.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const paired_cp_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const cp = try parseCp(cp_str);
            const paired = try parseCp(paired_cp_str);

            items[cp] = initField(Row, "bidi_mirroring", cp, paired, tracking);
        }
    }
};

const Blocks = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.block);
        @memset(items, .no_block);

        const file_path = "ucd/Blocks.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const block_name = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);

            const block = block_name_map.get(block_name) orelse blk: {
                std.log.err("Unknown block name: {s}", .{block_name});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .no_block;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = block;
            }
        }
    }
};

const block_name_map = std.StaticStringMap(types.Block).initComptime(.{
    .{ "Adlam", .adlam },
    .{ "Aegean Numbers", .aegean_numbers },
    .{ "Ahom", .ahom },
    .{ "Alchemical Symbols", .alchemical_symbols },
    .{ "Alphabetic Presentation Forms", .alphabetic_presentation_forms },
    .{ "Anatolian Hieroglyphs", .anatolian_hieroglyphs },
    .{ "Ancient Greek Musical Notation", .ancient_greek_musical_notation },
    .{ "Ancient Greek Numbers", .ancient_greek_numbers },
    .{ "Ancient Symbols", .ancient_symbols },
    .{ "Arabic Extended-A", .arabic_extended_a },
    .{ "Arabic Extended-B", .arabic_extended_b },
    .{ "Arabic Extended-C", .arabic_extended_c },
    .{ "Arabic Mathematical Alphabetic Symbols", .arabic_mathematical_alphabetic_symbols },
    .{ "Arabic Presentation Forms-A", .arabic_presentation_forms_a },
    .{ "Arabic Presentation Forms-B", .arabic_presentation_forms_b },
    .{ "Arabic Supplement", .arabic_supplement },
    .{ "Arabic", .arabic },
    .{ "Armenian", .armenian },
    .{ "Arrows", .arrows },
    .{ "Avestan", .avestan },
    .{ "Balinese", .balinese },
    .{ "Bamum Supplement", .bamum_supplement },
    .{ "Bamum", .bamum },
    .{ "Basic Latin", .basic_latin },
    .{ "Bassa Vah", .bassa_vah },
    .{ "Batak", .batak },
    .{ "Bengali", .bengali },
    .{ "Beria Erfe", .beria_erfe },
    .{ "Bhaiksuki", .bhaiksuki },
    .{ "Block Elements", .block_elements },
    .{ "Bopomofo Extended", .bopomofo_extended },
    .{ "Bopomofo", .bopomofo },
    .{ "Box Drawing", .box_drawing },
    .{ "Brahmi", .brahmi },
    .{ "Braille Patterns", .braille_patterns },
    .{ "Buginese", .buginese },
    .{ "Buhid", .buhid },
    .{ "Byzantine Musical Symbols", .byzantine_musical_symbols },
    .{ "CJK Compatibility Forms", .cjk_compatibility_forms },
    .{ "CJK Compatibility Ideographs Supplement", .cjk_compatibility_ideographs_supplement },
    .{ "CJK Compatibility Ideographs", .cjk_compatibility_ideographs },
    .{ "CJK Compatibility", .cjk_compatibility },
    .{ "CJK Radicals Supplement", .cjk_radicals_supplement },
    .{ "CJK Strokes", .cjk_strokes },
    .{ "CJK Symbols and Punctuation", .cjk_symbols_and_punctuation },
    .{ "CJK Unified Ideographs Extension A", .cjk_unified_ideographs_extension_a },
    .{ "CJK Unified Ideographs Extension B", .cjk_unified_ideographs_extension_b },
    .{ "CJK Unified Ideographs Extension C", .cjk_unified_ideographs_extension_c },
    .{ "CJK Unified Ideographs Extension D", .cjk_unified_ideographs_extension_d },
    .{ "CJK Unified Ideographs Extension E", .cjk_unified_ideographs_extension_e },
    .{ "CJK Unified Ideographs Extension F", .cjk_unified_ideographs_extension_f },
    .{ "CJK Unified Ideographs Extension G", .cjk_unified_ideographs_extension_g },
    .{ "CJK Unified Ideographs Extension H", .cjk_unified_ideographs_extension_h },
    .{ "CJK Unified Ideographs Extension I", .cjk_unified_ideographs_extension_i },
    .{ "CJK Unified Ideographs Extension J", .cjk_unified_ideographs_extension_j },
    .{ "CJK Unified Ideographs", .cjk_unified_ideographs },
    .{ "Carian", .carian },
    .{ "Caucasian Albanian", .caucasian_albanian },
    .{ "Chakma", .chakma },
    .{ "Cham", .cham },
    .{ "Cherokee Supplement", .cherokee_supplement },
    .{ "Cherokee", .cherokee },
    .{ "Chess Symbols", .chess_symbols },
    .{ "Chorasmian", .chorasmian },
    .{ "Combining Diacritical Marks Extended", .combining_diacritical_marks_extended },
    .{ "Combining Diacritical Marks Supplement", .combining_diacritical_marks_supplement },
    .{ "Combining Diacritical Marks for Symbols", .combining_diacritical_marks_for_symbols },
    .{ "Combining Diacritical Marks", .combining_diacritical_marks },
    .{ "Combining Half Marks", .combining_half_marks },
    .{ "Common Indic Number Forms", .common_indic_number_forms },
    .{ "Control Pictures", .control_pictures },
    .{ "Coptic Epact Numbers", .coptic_epact_numbers },
    .{ "Coptic", .coptic },
    .{ "Counting Rod Numerals", .counting_rod_numerals },
    .{ "Cuneiform Numbers and Punctuation", .cuneiform_numbers_and_punctuation },
    .{ "Cuneiform", .cuneiform },
    .{ "Currency Symbols", .currency_symbols },
    .{ "Cypriot Syllabary", .cypriot_syllabary },
    .{ "Cypro-Minoan", .cypro_minoan },
    .{ "Cyrillic Extended-A", .cyrillic_extended_a },
    .{ "Cyrillic Extended-B", .cyrillic_extended_b },
    .{ "Cyrillic Extended-C", .cyrillic_extended_c },
    .{ "Cyrillic Extended-D", .cyrillic_extended_d },
    .{ "Cyrillic Supplement", .cyrillic_supplement },
    .{ "Cyrillic", .cyrillic },
    .{ "Deseret", .deseret },
    .{ "Devanagari Extended", .devanagari_extended },
    .{ "Devanagari Extended-A", .devanagari_extended_a },
    .{ "Devanagari", .devanagari },
    .{ "Dingbats", .dingbats },
    .{ "Dives Akuru", .dives_akuru },
    .{ "Dogra", .dogra },
    .{ "Domino Tiles", .domino_tiles },
    .{ "Duployan", .duployan },
    .{ "Early Dynastic Cuneiform", .early_dynastic_cuneiform },
    .{ "Egyptian Hieroglyph Format Controls", .egyptian_hieroglyph_format_controls },
    .{ "Egyptian Hieroglyphs Extended-A", .egyptian_hieroglyphs_extended_a },
    .{ "Egyptian Hieroglyphs", .egyptian_hieroglyphs },
    .{ "Elbasan", .elbasan },
    .{ "Elymaic", .elymaic },
    .{ "Emoticons", .emoticons },
    .{ "Enclosed Alphanumeric Supplement", .enclosed_alphanumeric_supplement },
    .{ "Enclosed Alphanumerics", .enclosed_alphanumerics },
    .{ "Enclosed CJK Letters and Months", .enclosed_cjk_letters_and_months },
    .{ "Enclosed Ideographic Supplement", .enclosed_ideographic_supplement },
    .{ "Ethiopic Extended", .ethiopic_extended },
    .{ "Ethiopic Extended-A", .ethiopic_extended_a },
    .{ "Ethiopic Extended-B", .ethiopic_extended_b },
    .{ "Ethiopic Supplement", .ethiopic_supplement },
    .{ "Ethiopic", .ethiopic },
    .{ "Garay", .garay },
    .{ "General Punctuation", .general_punctuation },
    .{ "Geometric Shapes Extended", .geometric_shapes_extended },
    .{ "Geometric Shapes", .geometric_shapes },
    .{ "Georgian Extended", .georgian_extended },
    .{ "Georgian Supplement", .georgian_supplement },
    .{ "Georgian", .georgian },
    .{ "Glagolitic Supplement", .glagolitic_supplement },
    .{ "Glagolitic", .glagolitic },
    .{ "Gothic", .gothic },
    .{ "Grantha", .grantha },
    .{ "Greek Extended", .greek_extended },
    .{ "Greek and Coptic", .greek_and_coptic },
    .{ "Gujarati", .gujarati },
    .{ "Gunjala Gondi", .gunjala_gondi },
    .{ "Gurmukhi", .gurmukhi },
    .{ "Gurung Khema", .gurung_khema },
    .{ "Halfwidth and Fullwidth Forms", .halfwidth_and_fullwidth_forms },
    .{ "Hangul Compatibility Jamo", .hangul_compatibility_jamo },
    .{ "Hangul Jamo Extended-A", .hangul_jamo_extended_a },
    .{ "Hangul Jamo Extended-B", .hangul_jamo_extended_b },
    .{ "Hangul Jamo", .hangul_jamo },
    .{ "Hangul Syllables", .hangul_syllables },
    .{ "Hanifi Rohingya", .hanifi_rohingya },
    .{ "Hanunoo", .hanunoo },
    .{ "Hatran", .hatran },
    .{ "Hebrew", .hebrew },
    .{ "High Private Use Surrogates", .high_private_use_surrogates },
    .{ "High Surrogates", .high_surrogates },
    .{ "Hiragana", .hiragana },
    .{ "IPA Extensions", .ipa_extensions },
    .{ "Ideographic Description Characters", .ideographic_description_characters },
    .{ "Ideographic Symbols and Punctuation", .ideographic_symbols_and_punctuation },
    .{ "Imperial Aramaic", .imperial_aramaic },
    .{ "Indic Siyaq Numbers", .indic_siyaq_numbers },
    .{ "Inscriptional Pahlavi", .inscriptional_pahlavi },
    .{ "Inscriptional Parthian", .inscriptional_parthian },
    .{ "Javanese", .javanese },
    .{ "Kaithi", .kaithi },
    .{ "Kaktovik Numerals", .kaktovik_numerals },
    .{ "Kana Extended-A", .kana_extended_a },
    .{ "Kana Extended-B", .kana_extended_b },
    .{ "Kana Supplement", .kana_supplement },
    .{ "Kanbun", .kanbun },
    .{ "Kangxi Radicals", .kangxi_radicals },
    .{ "Kannada", .kannada },
    .{ "Katakana Phonetic Extensions", .katakana_phonetic_extensions },
    .{ "Katakana", .katakana },
    .{ "Kawi", .kawi },
    .{ "Kayah Li", .kayah_li },
    .{ "Kharoshthi", .kharoshthi },
    .{ "Khitan Small Script", .khitan_small_script },
    .{ "Khmer Symbols", .khmer_symbols },
    .{ "Khmer", .khmer },
    .{ "Khojki", .khojki },
    .{ "Khudawadi", .khudawadi },
    .{ "Kirat Rai", .kirat_rai },
    .{ "Lao", .lao },
    .{ "Latin Extended Additional", .latin_extended_additional },
    .{ "Latin Extended-A", .latin_extended_a },
    .{ "Latin Extended-B", .latin_extended_b },
    .{ "Latin Extended-C", .latin_extended_c },
    .{ "Latin Extended-D", .latin_extended_d },
    .{ "Latin Extended-E", .latin_extended_e },
    .{ "Latin Extended-F", .latin_extended_f },
    .{ "Latin Extended-G", .latin_extended_g },
    .{ "Latin-1 Supplement", .latin_1_supplement },
    .{ "Lepcha", .lepcha },
    .{ "Letterlike Symbols", .letterlike_symbols },
    .{ "Limbu", .limbu },
    .{ "Linear A", .linear_a },
    .{ "Linear B Ideograms", .linear_b_ideograms },
    .{ "Linear B Syllabary", .linear_b_syllabary },
    .{ "Lisu Supplement", .lisu_supplement },
    .{ "Lisu", .lisu },
    .{ "Low Surrogates", .low_surrogates },
    .{ "Lycian", .lycian },
    .{ "Lydian", .lydian },
    .{ "Mahajani", .mahajani },
    .{ "Mahjong Tiles", .mahjong_tiles },
    .{ "Makasar", .makasar },
    .{ "Malayalam", .malayalam },
    .{ "Mandaic", .mandaic },
    .{ "Manichaean", .manichaean },
    .{ "Marchen", .marchen },
    .{ "Masaram Gondi", .masaram_gondi },
    .{ "Mathematical Alphanumeric Symbols", .mathematical_alphanumeric_symbols },
    .{ "Mathematical Operators", .mathematical_operators },
    .{ "Mayan Numerals", .mayan_numerals },
    .{ "Medefaidrin", .medefaidrin },
    .{ "Meetei Mayek Extensions", .meetei_mayek_extensions },
    .{ "Meetei Mayek", .meetei_mayek },
    .{ "Mende Kikakui", .mende_kikakui },
    .{ "Meroitic Cursive", .meroitic_cursive },
    .{ "Meroitic Hieroglyphs", .meroitic_hieroglyphs },
    .{ "Miao", .miao },
    .{ "Miscellaneous Mathematical Symbols-A", .miscellaneous_mathematical_symbols_a },
    .{ "Miscellaneous Mathematical Symbols-B", .miscellaneous_mathematical_symbols_b },
    .{ "Miscellaneous Symbols Supplement", .miscellaneous_symbols_supplement },
    .{ "Miscellaneous Symbols and Arrows", .miscellaneous_symbols_and_arrows },
    .{ "Miscellaneous Symbols and Pictographs", .miscellaneous_symbols_and_pictographs },
    .{ "Miscellaneous Symbols", .miscellaneous_symbols },
    .{ "Miscellaneous Technical", .miscellaneous_technical },
    .{ "Modi", .modi },
    .{ "Modifier Tone Letters", .modifier_tone_letters },
    .{ "Mongolian Supplement", .mongolian_supplement },
    .{ "Mongolian", .mongolian },
    .{ "Mro", .mro },
    .{ "Multani", .multani },
    .{ "Musical Symbols", .musical_symbols },
    .{ "Myanmar Extended-A", .myanmar_extended_a },
    .{ "Myanmar Extended-B", .myanmar_extended_b },
    .{ "Myanmar Extended-C", .myanmar_extended_c },
    .{ "Myanmar", .myanmar },
    .{ "NKo", .nko },
    .{ "Nabataean", .nabataean },
    .{ "Nag Mundari", .nag_mundari },
    .{ "Nandinagari", .nandinagari },
    .{ "New Tai Lue", .new_tai_lue },
    .{ "Newa", .newa },
    .{ "Number Forms", .number_forms },
    .{ "Nushu", .nushu },
    .{ "Nyiakeng Puachue Hmong", .nyiakeng_puachue_hmong },
    .{ "Ogham", .ogham },
    .{ "Ol Chiki", .ol_chiki },
    .{ "Ol Onal", .ol_onal },
    .{ "Old Hungarian", .old_hungarian },
    .{ "Old Italic", .old_italic },
    .{ "Old North Arabian", .old_north_arabian },
    .{ "Old Permic", .old_permic },
    .{ "Old Persian", .old_persian },
    .{ "Old Sogdian", .old_sogdian },
    .{ "Old South Arabian", .old_south_arabian },
    .{ "Old Turkic", .old_turkic },
    .{ "Old Uyghur", .old_uyghur },
    .{ "Optical Character Recognition", .optical_character_recognition },
    .{ "Oriya", .oriya },
    .{ "Ornamental Dingbats", .ornamental_dingbats },
    .{ "Osage", .osage },
    .{ "Osmanya", .osmanya },
    .{ "Ottoman Siyaq Numbers", .ottoman_siyaq_numbers },
    .{ "Pahawh Hmong", .pahawh_hmong },
    .{ "Palmyrene", .palmyrene },
    .{ "Pau Cin Hau", .pau_cin_hau },
    .{ "Phags-pa", .phags_pa },
    .{ "Phaistos Disc", .phaistos_disc },
    .{ "Phoenician", .phoenician },
    .{ "Phonetic Extensions Supplement", .phonetic_extensions_supplement },
    .{ "Phonetic Extensions", .phonetic_extensions },
    .{ "Playing Cards", .playing_cards },
    .{ "Private Use Area", .private_use_area },
    .{ "Psalter Pahlavi", .psalter_pahlavi },
    .{ "Rejang", .rejang },
    .{ "Rumi Numeral Symbols", .rumi_numeral_symbols },
    .{ "Runic", .runic },
    .{ "Samaritan", .samaritan },
    .{ "Saurashtra", .saurashtra },
    .{ "Sharada Supplement", .sharada_supplement },
    .{ "Sharada", .sharada },
    .{ "Shavian", .shavian },
    .{ "Shorthand Format Controls", .shorthand_format_controls },
    .{ "Siddham", .siddham },
    .{ "Sidetic", .sidetic },
    .{ "Sinhala Archaic Numbers", .sinhala_archaic_numbers },
    .{ "Sinhala", .sinhala },
    .{ "Small Form Variants", .small_form_variants },
    .{ "Small Kana Extension", .small_kana_extension },
    .{ "Sogdian", .sogdian },
    .{ "Sora Sompeng", .sora_sompeng },
    .{ "Soyombo", .soyombo },
    .{ "Spacing Modifier Letters", .spacing_modifier_letters },
    .{ "Specials", .specials },
    .{ "Sundanese Supplement", .sundanese_supplement },
    .{ "Sundanese", .sundanese },
    .{ "Sunuwar", .sunuwar },
    .{ "Superscripts and Subscripts", .superscripts_and_subscripts },
    .{ "Supplemental Arrows-A", .supplemental_arrows_a },
    .{ "Supplemental Arrows-B", .supplemental_arrows_b },
    .{ "Supplemental Arrows-C", .supplemental_arrows_c },
    .{ "Supplemental Mathematical Operators", .supplemental_mathematical_operators },
    .{ "Supplemental Punctuation", .supplemental_punctuation },
    .{ "Supplemental Symbols and Pictographs", .supplemental_symbols_and_pictographs },
    .{ "Supplementary Private Use Area-A", .supplementary_private_use_area_a },
    .{ "Supplementary Private Use Area-B", .supplementary_private_use_area_b },
    .{ "Sutton SignWriting", .sutton_signwriting },
    .{ "Syloti Nagri", .syloti_nagri },
    .{ "Symbols and Pictographs Extended-A", .symbols_and_pictographs_extended_a },
    .{ "Symbols for Legacy Computing Supplement", .symbols_for_legacy_computing_supplement },
    .{ "Symbols for Legacy Computing", .symbols_for_legacy_computing },
    .{ "Syriac Supplement", .syriac_supplement },
    .{ "Syriac", .syriac },
    .{ "Tagalog", .tagalog },
    .{ "Tagbanwa", .tagbanwa },
    .{ "Tags", .tags },
    .{ "Tai Le", .tai_le },
    .{ "Tai Tham", .tai_tham },
    .{ "Tai Viet", .tai_viet },
    .{ "Tai Xuan Jing Symbols", .tai_xuan_jing_symbols },
    .{ "Tai Yo", .tai_yo },
    .{ "Takri", .takri },
    .{ "Tamil Supplement", .tamil_supplement },
    .{ "Tamil", .tamil },
    .{ "Tangsa", .tangsa },
    .{ "Tangut Components Supplement", .tangut_components_supplement },
    .{ "Tangut Components", .tangut_components },
    .{ "Tangut Supplement", .tangut_supplement },
    .{ "Tangut", .tangut },
    .{ "Telugu", .telugu },
    .{ "Thaana", .thaana },
    .{ "Thai", .thai },
    .{ "Tibetan", .tibetan },
    .{ "Tifinagh", .tifinagh },
    .{ "Tirhuta", .tirhuta },
    .{ "Todhri", .todhri },
    .{ "Tolong Siki", .tolong_siki },
    .{ "Toto", .toto },
    .{ "Transport and Map Symbols", .transport_and_map_symbols },
    .{ "Tulu-Tigalari", .tulu_tigalari },
    .{ "Ugaritic", .ugaritic },
    .{ "Unified Canadian Aboriginal Syllabics Extended", .unified_canadian_aboriginal_syllabics_extended },
    .{ "Unified Canadian Aboriginal Syllabics Extended-A", .unified_canadian_aboriginal_syllabics_extended_a },
    .{ "Unified Canadian Aboriginal Syllabics", .unified_canadian_aboriginal_syllabics },
    .{ "Vai", .vai },
    .{ "Variation Selectors Supplement", .variation_selectors_supplement },
    .{ "Variation Selectors", .variation_selectors },
    .{ "Vedic Extensions", .vedic_extensions },
    .{ "Vertical Forms", .vertical_forms },
    .{ "Vithkuqi", .vithkuqi },
    .{ "Wancho", .wancho },
    .{ "Warang Citi", .warang_citi },
    .{ "Yezidi", .yezidi },
    .{ "Yi Radicals", .yi_radicals },
    .{ "Yi Syllables", .yi_syllables },
    .{ "Yijing Hexagram Symbols", .yijing_hexagram_symbols },
    .{ "Zanabazar Square", .zanabazar_square },
    .{ "Znamenny Musical Notation", .znamenny_musical_notation },
});

const Scripts = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.script);
        @memset(items, .unknown);

        const file_path = "ucd/Scripts.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const script_name = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);
            const script = script_name_map.get(script_name) orelse blk: {
                std.log.err("Unknown script name: {s}", .{script_name});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .unknown;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = script;
            }
        }
    }
};

const script_name_map = std.StaticStringMap(types.Script).initComptime(.{
    .{ "Adlam", .adlam },
    .{ "Ahom", .ahom },
    .{ "Anatolian_Hieroglyphs", .anatolian_hieroglyphs },
    .{ "Arabic", .arabic },
    .{ "Armenian", .armenian },
    .{ "Avestan", .avestan },
    .{ "Balinese", .balinese },
    .{ "Bamum", .bamum },
    .{ "Bassa_Vah", .bassa_vah },
    .{ "Batak", .batak },
    .{ "Bengali", .bengali },
    .{ "Beria_Erfe", .beria_erfe },
    .{ "Bhaiksuki", .bhaiksuki },
    .{ "Bopomofo", .bopomofo },
    .{ "Brahmi", .brahmi },
    .{ "Braille", .braille },
    .{ "Buginese", .buginese },
    .{ "Buhid", .buhid },
    .{ "Canadian_Aboriginal", .canadian_aboriginal },
    .{ "Carian", .carian },
    .{ "Caucasian_Albanian", .caucasian_albanian },
    .{ "Chakma", .chakma },
    .{ "Cham", .cham },
    .{ "Cherokee", .cherokee },
    .{ "Chorasmian", .chorasmian },
    .{ "Common", .common },
    .{ "Coptic", .coptic },
    .{ "Cuneiform", .cuneiform },
    .{ "Cypriot", .cypriot },
    .{ "Cypro_Minoan", .cypro_minoan },
    .{ "Cyrillic", .cyrillic },
    .{ "Deseret", .deseret },
    .{ "Devanagari", .devanagari },
    .{ "Dives_Akuru", .dives_akuru },
    .{ "Dogra", .dogra },
    .{ "Duployan", .duployan },
    .{ "Egyptian_Hieroglyphs", .egyptian_hieroglyphs },
    .{ "Elbasan", .elbasan },
    .{ "Elymaic", .elymaic },
    .{ "Ethiopic", .ethiopic },
    .{ "Garay", .garay },
    .{ "Georgian", .georgian },
    .{ "Glagolitic", .glagolitic },
    .{ "Gothic", .gothic },
    .{ "Grantha", .grantha },
    .{ "Greek", .greek },
    .{ "Gujarati", .gujarati },
    .{ "Gunjala_Gondi", .gunjala_gondi },
    .{ "Gurmukhi", .gurmukhi },
    .{ "Gurung_Khema", .gurung_khema },
    .{ "Han", .han },
    .{ "Hangul", .hangul },
    .{ "Hanifi_Rohingya", .hanifi_rohingya },
    .{ "Hanunoo", .hanunoo },
    .{ "Hatran", .hatran },
    .{ "Hebrew", .hebrew },
    .{ "Hiragana", .hiragana },
    .{ "Imperial_Aramaic", .imperial_aramaic },
    .{ "Inherited", .inherited },
    .{ "Inscriptional_Pahlavi", .inscriptional_pahlavi },
    .{ "Inscriptional_Parthian", .inscriptional_parthian },
    .{ "Javanese", .javanese },
    .{ "Kaithi", .kaithi },
    .{ "Kannada", .kannada },
    .{ "Katakana", .katakana },
    .{ "Kawi", .kawi },
    .{ "Kayah_Li", .kayah_li },
    .{ "Kharoshthi", .kharoshthi },
    .{ "Khitan_Small_Script", .khitan_small_script },
    .{ "Khmer", .khmer },
    .{ "Khojki", .khojki },
    .{ "Khudawadi", .khudawadi },
    .{ "Kirat_Rai", .kirat_rai },
    .{ "Lao", .lao },
    .{ "Latin", .latin },
    .{ "Lepcha", .lepcha },
    .{ "Limbu", .limbu },
    .{ "Linear_A", .linear_a },
    .{ "Linear_B", .linear_b },
    .{ "Lisu", .lisu },
    .{ "Lycian", .lycian },
    .{ "Lydian", .lydian },
    .{ "Mahajani", .mahajani },
    .{ "Makasar", .makasar },
    .{ "Malayalam", .malayalam },
    .{ "Mandaic", .mandaic },
    .{ "Manichaean", .manichaean },
    .{ "Marchen", .marchen },
    .{ "Masaram_Gondi", .masaram_gondi },
    .{ "Medefaidrin", .medefaidrin },
    .{ "Meetei_Mayek", .meetei_mayek },
    .{ "Mende_Kikakui", .mende_kikakui },
    .{ "Meroitic_Cursive", .meroitic_cursive },
    .{ "Meroitic_Hieroglyphs", .meroitic_hieroglyphs },
    .{ "Miao", .miao },
    .{ "Modi", .modi },
    .{ "Mongolian", .mongolian },
    .{ "Mro", .mro },
    .{ "Multani", .multani },
    .{ "Myanmar", .myanmar },
    .{ "Nabataean", .nabataean },
    .{ "Nag_Mundari", .nag_mundari },
    .{ "Nandinagari", .nandinagari },
    .{ "New_Tai_Lue", .new_tai_lue },
    .{ "Newa", .newa },
    .{ "Nko", .nko },
    .{ "Nushu", .nushu },
    .{ "Nyiakeng_Puachue_Hmong", .nyiakeng_puachue_hmong },
    .{ "Ogham", .ogham },
    .{ "Ol_Chiki", .ol_chiki },
    .{ "Ol_Onal", .ol_onal },
    .{ "Old_Hungarian", .old_hungarian },
    .{ "Old_Italic", .old_italic },
    .{ "Old_North_Arabian", .old_north_arabian },
    .{ "Old_Permic", .old_permic },
    .{ "Old_Persian", .old_persian },
    .{ "Old_Sogdian", .old_sogdian },
    .{ "Old_South_Arabian", .old_south_arabian },
    .{ "Old_Turkic", .old_turkic },
    .{ "Old_Uyghur", .old_uyghur },
    .{ "Oriya", .oriya },
    .{ "Osage", .osage },
    .{ "Osmanya", .osmanya },
    .{ "Pahawh_Hmong", .pahawh_hmong },
    .{ "Palmyrene", .palmyrene },
    .{ "Pau_Cin_Hau", .pau_cin_hau },
    .{ "Phags_Pa", .phags_pa },
    .{ "Phoenician", .phoenician },
    .{ "Psalter_Pahlavi", .psalter_pahlavi },
    .{ "Rejang", .rejang },
    .{ "Runic", .runic },
    .{ "Samaritan", .samaritan },
    .{ "Saurashtra", .saurashtra },
    .{ "Sharada", .sharada },
    .{ "Shavian", .shavian },
    .{ "Siddham", .siddham },
    .{ "Sidetic", .sidetic },
    .{ "SignWriting", .signwriting },
    .{ "Sinhala", .sinhala },
    .{ "Sogdian", .sogdian },
    .{ "Sora_Sompeng", .sora_sompeng },
    .{ "Soyombo", .soyombo },
    .{ "Sundanese", .sundanese },
    .{ "Sunuwar", .sunuwar },
    .{ "Syloti_Nagri", .syloti_nagri },
    .{ "Syriac", .syriac },
    .{ "Tagalog", .tagalog },
    .{ "Tagbanwa", .tagbanwa },
    .{ "Tai_Le", .tai_le },
    .{ "Tai_Tham", .tai_tham },
    .{ "Tai_Viet", .tai_viet },
    .{ "Tai_Yo", .tai_yo },
    .{ "Takri", .takri },
    .{ "Tamil", .tamil },
    .{ "Tangsa", .tangsa },
    .{ "Tangut", .tangut },
    .{ "Telugu", .telugu },
    .{ "Thaana", .thaana },
    .{ "Thai", .thai },
    .{ "Tibetan", .tibetan },
    .{ "Tifinagh", .tifinagh },
    .{ "Tirhuta", .tirhuta },
    .{ "Todhri", .todhri },
    .{ "Tolong_Siki", .tolong_siki },
    .{ "Toto", .toto },
    .{ "Tulu_Tigalari", .tulu_tigalari },
    .{ "Ugaritic", .ugaritic },
    .{ "Vai", .vai },
    .{ "Vithkuqi", .vithkuqi },
    .{ "Wancho", .wancho },
    .{ "Warang_Citi", .warang_citi },
    .{ "Yezidi", .yezidi },
    .{ "Yi", .yi },
    .{ "Zanabazar_Square", .zanabazar_square },
});

const JoiningType = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.joining_type);
        @memset(items, .non_joining);

        const file_path = "ucd/extracted/DerivedJoiningType.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const jt_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);
            const jt = joining_type_map.get(jt_str) orelse blk: {
                std.log.err("Unknown joining type: {s}", .{jt_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .non_joining;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = jt;
            }
        }
    }
};

const joining_type_map = std.StaticStringMap(types.JoiningType).initComptime(.{
    .{ "C", .join_causing },
    .{ "D", .dual_joining },
    .{ "L", .left_joining },
    .{ "R", .right_joining },
    .{ "T", .transparent },
});

const JoiningGroup = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.joining_group);
        @memset(items, .no_joining_group);

        const file_path = "ucd/extracted/DerivedJoiningGroup.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const jg_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);
            const jg = joining_group_map.get(jg_str) orelse blk: {
                std.log.err("Unknown joining group: {s}", .{jg_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .no_joining_group;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = jg;
            }
        }
    }
};

const joining_group_map = std.StaticStringMap(types.JoiningGroup).initComptime(.{
    .{ "No_Joining_Group", .no_joining_group },
    .{ "African_Feh", .african_feh },
    .{ "African_Noon", .african_noon },
    .{ "African_Qaf", .african_qaf },
    .{ "Ain", .ain },
    .{ "Alaph", .alaph },
    .{ "Alef", .alef },
    .{ "Beh", .beh },
    .{ "Beth", .beth },
    .{ "Burushaski_Yeh_Barree", .burushaski_yeh_barree },
    .{ "Dal", .dal },
    .{ "Dalath_Rish", .dalath_rish },
    .{ "E", .e },
    .{ "Farsi_Yeh", .farsi_yeh },
    .{ "Fe", .fe },
    .{ "Feh", .feh },
    .{ "Final_Semkath", .final_semkath },
    .{ "Gaf", .gaf },
    .{ "Gamal", .gamal },
    .{ "Hah", .hah },
    .{ "Hanifi_Rohingya_Kinna_Ya", .hanifi_rohingya_kinna_ya },
    .{ "Hanifi_Rohingya_Pa", .hanifi_rohingya_pa },
    .{ "He", .he },
    .{ "Heh", .heh },
    .{ "Heh_Goal", .heh_goal },
    .{ "Heth", .heth },
    .{ "Kaf", .kaf },
    .{ "Kaph", .kaph },
    .{ "Kashmiri_Yeh", .kashmiri_yeh },
    .{ "Khaph", .khaph },
    .{ "Knotted_Heh", .knotted_heh },
    .{ "Lam", .lam },
    .{ "Lamadh", .lamadh },
    .{ "Malayalam_Bha", .malayalam_bha },
    .{ "Malayalam_Ja", .malayalam_ja },
    .{ "Malayalam_Lla", .malayalam_lla },
    .{ "Malayalam_Llla", .malayalam_llla },
    .{ "Malayalam_Nga", .malayalam_nga },
    .{ "Malayalam_Nna", .malayalam_nna },
    .{ "Malayalam_Nnna", .malayalam_nnna },
    .{ "Malayalam_Nya", .malayalam_nya },
    .{ "Malayalam_Ra", .malayalam_ra },
    .{ "Malayalam_Ssa", .malayalam_ssa },
    .{ "Malayalam_Tta", .malayalam_tta },
    .{ "Manichaean_Aleph", .manichaean_aleph },
    .{ "Manichaean_Ayin", .manichaean_ayin },
    .{ "Manichaean_Beth", .manichaean_beth },
    .{ "Manichaean_Daleth", .manichaean_daleth },
    .{ "Manichaean_Dhamedh", .manichaean_dhamedh },
    .{ "Manichaean_Five", .manichaean_five },
    .{ "Manichaean_Gimel", .manichaean_gimel },
    .{ "Manichaean_Heth", .manichaean_heth },
    .{ "Manichaean_Hundred", .manichaean_hundred },
    .{ "Manichaean_Kaph", .manichaean_kaph },
    .{ "Manichaean_Lamedh", .manichaean_lamedh },
    .{ "Manichaean_Mem", .manichaean_mem },
    .{ "Manichaean_Nun", .manichaean_nun },
    .{ "Manichaean_One", .manichaean_one },
    .{ "Manichaean_Pe", .manichaean_pe },
    .{ "Manichaean_Qoph", .manichaean_qoph },
    .{ "Manichaean_Resh", .manichaean_resh },
    .{ "Manichaean_Sadhe", .manichaean_sadhe },
    .{ "Manichaean_Samekh", .manichaean_samekh },
    .{ "Manichaean_Taw", .manichaean_taw },
    .{ "Manichaean_Ten", .manichaean_ten },
    .{ "Manichaean_Teth", .manichaean_teth },
    .{ "Manichaean_Thamedh", .manichaean_thamedh },
    .{ "Manichaean_Twenty", .manichaean_twenty },
    .{ "Manichaean_Waw", .manichaean_waw },
    .{ "Manichaean_Yodh", .manichaean_yodh },
    .{ "Manichaean_Zayin", .manichaean_zayin },
    .{ "Meem", .meem },
    .{ "Mim", .mim },
    .{ "Noon", .noon },
    .{ "Nun", .nun },
    .{ "Nya", .nya },
    .{ "Pe", .pe },
    .{ "Qaf", .qaf },
    .{ "Qaph", .qaph },
    .{ "Reh", .reh },
    .{ "Reversed_Pe", .reversed_pe },
    .{ "Rohingya_Yeh", .rohingya_yeh },
    .{ "Sad", .sad },
    .{ "Sadhe", .sadhe },
    .{ "Seen", .seen },
    .{ "Semkath", .semkath },
    .{ "Shin", .shin },
    .{ "Straight_Waw", .straight_waw },
    .{ "Swash_Kaf", .swash_kaf },
    .{ "Syriac_Waw", .syriac_waw },
    .{ "Tah", .tah },
    .{ "Taw", .taw },
    .{ "Teh_Marbuta", .teh_marbuta },
    .{ "Teh_Marbuta_Goal", .teh_marbuta_goal },
    .{ "Teth", .teth },
    .{ "Thin_Noon", .thin_noon },
    .{ "Thin_Yeh", .thin_yeh },
    .{ "Vertical_Tail", .vertical_tail },
    .{ "Waw", .waw },
    .{ "Yeh", .yeh },
    .{ "Yeh_Barree", .yeh_barree },
    .{ "Yeh_With_Tail", .yeh_with_tail },
    .{ "Yudh", .yudh },
    .{ "Yudh_He", .yudh_he },
    .{ "Zain", .zain },
    .{ "Zhain", .zhain },
});

const CompositionExclusions = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.is_composition_exclusion);
        @memset(items, false);

        const file_path = "ucd/CompositionExclusions.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            const cp_str = trimmed;
            const range = try parseRange(cp_str);

            for (range.start..range.end) |cp| {
                items[cp] = true;
            }
        }
    }
};

const IndicPositionalCategory = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.indic_positional_category);
        @memset(items, .not_applicable);

        const file_path = "ucd/IndicPositionalCategory.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const ipc_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);
            const ipc = indic_positional_category_map.get(ipc_str) orelse blk: {
                std.log.err("Unknown indic positional category: {s}", .{ipc_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .not_applicable;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = ipc;
            }
        }
    }
};

const indic_positional_category_map = std.StaticStringMap(types.IndicPositionalCategory).initComptime(.{
    .{ "Not_Applicable", .not_applicable },
    .{ "Right", .right },
    .{ "Left", .left },
    .{ "Visual_Order_Left", .visual_order_left },
    .{ "Left_And_Right", .left_and_right },
    .{ "Top", .top },
    .{ "Bottom", .bottom },
    .{ "Top_And_Bottom", .top_and_bottom },
    .{ "Top_And_Right", .top_and_right },
    .{ "Top_And_Left", .top_and_left },
    .{ "Top_And_Left_And_Right", .top_and_left_and_right },
    .{ "Bottom_And_Right", .bottom_and_right },
    .{ "Bottom_And_Left", .bottom_and_left },
    .{ "Top_And_Bottom_And_Right", .top_and_bottom_and_right },
    .{ "Top_And_Bottom_And_Left", .top_and_bottom_and_left },
    .{ "Overstruck", .overstruck },
});

const IndicSyllabicCategory = struct {
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
        _ = inputs;
        _ = backing;
        _ = tracking;

        rows.len = config.num_code_points;
        const items = rows.items(.indic_syllabic_category);
        @memset(items, .other);

        const file_path = "ucd/IndicSyllabicCategory.txt";

        const content = try readFile(allocator, io, file_path);
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = trim(line);
            if (trimmed.len == 0) continue;

            var parts = std.mem.splitScalar(u8, trimmed, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t\r");
            const isc_str = std.mem.trim(u8, parts.next().?, " \t\r");

            const range = try parseRange(cp_str);
            const isc = indic_syllabic_category_map.get(isc_str) orelse blk: {
                std.log.err("Unknown indic syllabic category: {s}", .{isc_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .other;
                }
            };

            for (range.start..range.end) |cp| {
                items[cp] = isc;
            }
        }
    }
};

const indic_syllabic_category_map = std.StaticStringMap(types.IndicSyllabicCategory).initComptime(.{
    .{ "Other", .other },
    .{ "Bindu", .bindu },
    .{ "Visarga", .visarga },
    .{ "Avagraha", .avagraha },
    .{ "Nukta", .nukta },
    .{ "Virama", .virama },
    .{ "Pure_Killer", .pure_killer },
    .{ "Reordering_Killer", .reordering_killer },
    .{ "Invisible_Stacker", .invisible_stacker },
    .{ "Vowel_Independent", .vowel_independent },
    .{ "Vowel_Dependent", .vowel_dependent },
    .{ "Vowel", .vowel },
    .{ "Consonant_Placeholder", .consonant_placeholder },
    .{ "Consonant", .consonant },
    .{ "Consonant_Dead", .consonant_dead },
    .{ "Consonant_With_Stacker", .consonant_with_stacker },
    .{ "Consonant_Prefixed", .consonant_prefixed },
    .{ "Consonant_Preceding_Repha", .consonant_preceding_repha },
    .{ "Consonant_Initial_Postfixed", .consonant_initial_postfixed },
    .{ "Consonant_Succeeding_Repha", .consonant_succeeding_repha },
    .{ "Consonant_Subjoined", .consonant_subjoined },
    .{ "Consonant_Medial", .consonant_medial },
    .{ "Consonant_Final", .consonant_final },
    .{ "Consonant_Head_Letter", .consonant_head_letter },
    .{ "Modifying_Letter", .modifying_letter },
    .{ "Tone_Letter", .tone_letter },
    .{ "Tone_Mark", .tone_mark },
    .{ "Gemination_Mark", .gemination_mark },
    .{ "Cantillation_Mark", .cantillation_mark },
    .{ "Register_Shifter", .register_shifter },
    .{ "Syllable_Modifier", .syllable_modifier },
    .{ "Consonant_Killer", .consonant_killer },
    .{ "Non_Joiner", .non_joiner },
    .{ "Joiner", .joiner },
    .{ "Number_Joiner", .number_joiner },
    .{ "Number", .number },
    .{ "Brahmi_Joining_Number", .brahmi_joining_number },
});

const CaseFoldingSimple = struct {
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
        const items = rows.items(.case_folding_simple);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            const d = input.case_folding_simple_only.unshift(cp) orelse
                input.case_folding_common_only.unshift(cp) orelse
                input.case_folding_turkish_only.unshift(cp) orelse
                cp;

            items[i] = initField(Row, "case_folding_simple", cp, d, tracking);
        }
    }
};

const CaseFoldingFull = struct {
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
        const items = rows.items(.case_folding_full);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            var buffer: [1]u21 = undefined;
            const input = inputs.get(i);
            const full_only = input.case_folding_full_only;
            const common_only = input.case_folding_common_only.unshift(cp);

            const mapping = if (full_only.len > 0)
                full_only.valueWith(backing.case_folding_full_only, &buffer, cp)
            else blk: {
                buffer[0] = common_only orelse cp;
                break :blk &buffer;
            };

            items[i] = try initAllocField(Row, "case_folding_full", allocator, cp, mapping, tracking);
        }
    }
};

const LowercaseMapping = struct {
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
        const items = rows.items(.lowercase_mapping);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            const use_special = input.has_special_casing and input.special_casing_condition.len == 0;

            var buffer: [1]u21 = undefined;
            const mapping = if (use_special)
                input.special_lowercase_mapping.valueWith(backing.special_lowercase_mapping, &buffer, cp)
            else blk: {
                buffer[0] = input.simple_lowercase_mapping.unshift(cp);
                break :blk &buffer;
            };

            items[i] = try initAllocField(Row, "lowercase_mapping", allocator, cp, mapping, tracking);
        }
    }
};

const TitlecaseMapping = struct {
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
        const items = rows.items(.titlecase_mapping);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            const use_special = input.has_special_casing and input.special_casing_condition.len == 0;

            var buffer: [1]u21 = undefined;
            const mapping = if (use_special)
                input.special_titlecase_mapping.valueWith(backing.special_titlecase_mapping, &buffer, cp)
            else blk: {
                buffer[0] = input.simple_titlecase_mapping.unshift(cp);
                break :blk &buffer;
            };

            items[i] = try initAllocField(Row, "titlecase_mapping", allocator, cp, mapping, tracking);
        }
    }
};

const UppercaseMapping = struct {
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
        const items = rows.items(.uppercase_mapping);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            const use_special = input.has_special_casing and input.special_casing_condition.len == 0;

            var buffer: [1]u21 = undefined;
            const mapping = if (use_special)
                input.special_uppercase_mapping.valueWith(backing.special_uppercase_mapping, &buffer, cp)
            else blk: {
                buffer[0] = input.simple_uppercase_mapping.unshift(cp);
                break :blk &buffer;
            };

            items[i] = try initAllocField(Row, "uppercase_mapping", allocator, cp, mapping, tracking);
        }
    }
};

const GraphemeBreakDerived = struct {
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
        const items = rows.items(.grapheme_break);
        for (0..config.num_code_points) |i| {
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            const is_emoji_modifier = input.is_emoji_modifier;
            const is_emoji_modifier_base = input.is_emoji_modifier_base;
            const is_extended_pictographic = input.is_extended_pictographic;
            const is_emoji_component = input.is_emoji_component;
            const original_grapheme_break = input.original_grapheme_break;
            const indic_conjunct_break_val = input.indic_conjunct_break;

            const grapheme_break: types.GraphemeBreak = if (is_emoji_modifier) blk: {
                inlineAssert(original_grapheme_break == .extend);
                inlineAssert(!is_extended_pictographic and is_emoji_component);
                break :blk .emoji_modifier;
            } else if (is_emoji_modifier_base) blk: {
                inlineAssert(original_grapheme_break == .other);
                inlineAssert(is_extended_pictographic);
                break :blk .emoji_modifier_base;
            } else if (is_extended_pictographic) blk: {
                inlineAssert(original_grapheme_break == .other);
                break :blk .extended_pictographic;
            } else switch (indic_conjunct_break_val) {
                .none => blk: {
                    @setEvalBranchQuota(50_000);
                    break :blk switch (original_grapheme_break) {
                        .extend => blk2: {
                            if (cp == config.zero_width_non_joiner) {
                                break :blk2 .zwnj;
                            } else {
                                std.log.err(
                                    "Found an `extend` grapheme break that is Indic conjunct break `none` (and not zwnj): {x}",
                                    .{cp},
                                );
                                unreachable;
                            }
                        },
                        inline else => |o| comptime std.meta.stringToEnum(
                            types.GraphemeBreak,
                            @tagName(o),
                        ) orelse unreachable,
                    };
                },
                .extend => blk: {
                    if (cp == config.zero_width_joiner) {
                        inlineAssert(original_grapheme_break == .zwj);
                        break :blk .zwj;
                    } else {
                        inlineAssert(original_grapheme_break == .extend);
                        break :blk .indic_conjunct_break_extend;
                    }
                },
                .linker => blk: {
                    inlineAssert(original_grapheme_break == .extend);
                    break :blk .indic_conjunct_break_linker;
                },
                .consonant => blk: {
                    inlineAssert(original_grapheme_break == .other);
                    break :blk .indic_conjunct_break_consonant;
                },
            };

            items[i] = grapheme_break;
        }
    }
};

const GraphemeBreakNoControlComponent = struct {
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
        const items = rows.items(.grapheme_break_no_control);
        const input_items = inputs.items(.grapheme_break);
        for (0..config.num_code_points) |i| {
            items[i] = switch (input_items[i]) {
                .control, .cr, .lf => .other,
                inline else => |tag| comptime std.meta.stringToEnum(
                    types.GraphemeBreakNoControl,
                    @tagName(tag),
                ) orelse unreachable,
            };
        }
    }
};

const Wcwidth = struct {
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
            const cp: u21 = @intCast(i);
            const input = inputs.get(i);
            var row: Row = undefined;
            const gc = input.general_category;

            var width: u2 = undefined;

            if (gc == .other_control or
                gc == .other_surrogate or
                gc == .separator_line or
                gc == .separator_paragraph)
            {
                width = 0;
            } else if (cp == 0x00AD) {
                width = 1;
            } else if (input.is_default_ignorable) {
                width = 0;
            } else if (cp == 0x2E3A) {
                width = 2;
            } else if (cp == 0x2E3B) {
                width = 3;
            } else if (input.east_asian_width == .wide or input.east_asian_width == .fullwidth) {
                width = 2;
            } else if (input.grapheme_break == .regional_indicator) {
                width = 2;
            } else {
                width = 1;
            }

            if (cp == 0x20E3) {
                setBuiltField(&row, "wcwidth_standalone", 2);
            } else {
                setBuiltField(&row, "wcwidth_standalone", width);
            }

            if (width == 0 or
                input.is_emoji_modifier or
                gc == .mark_nonspacing or
                gc == .mark_enclosing or
                input.grapheme_break == .v or
                input.grapheme_break == .t or
                input.grapheme_break == .prepend)
            {
                setBuiltField(&row, "wcwidth_zero_in_grapheme", true);
            } else {
                setBuiltField(&row, "wcwidth_zero_in_grapheme", false);
            }

            rows.append(row);
        }
    }
};
