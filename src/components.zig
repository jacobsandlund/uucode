const std = @import("std");
const config = @import("config.zig");
const types = @import("types.zig");
const inlineAssert = config.quirks.inlineAssert;

const setBuiltField = config.setBuiltField;
const setOptionalField = config.setOptionalField;
const setShiftField = config.setShiftField;
const setField = config.setField;

pub const build_components: []const config.Component = &.{
    .{
        .Impl = UnicodeData,
        .fields = &.{
            "name",
            "general_category",
            "canonical_combining_class",
            "bidi_class",
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
    .{ .Impl = EmojiVs, .fields = &.{"is_emoji_vs_base"} },
};

pub const get_components: []const config.Component = &.{};

pub fn parseCp(str: []const u8) !u21 {
    return std.fmt.parseInt(u21, str, 16);
}

test "parseCp" {
    try std.testing.expectEqual(0x0000, try parseCp("0000"));
    try std.testing.expectEqual(0x1F600, try parseCp("1F600"));
}

pub fn parseRange(str: []const u8) !struct { start: u21, end: u21 } {
    if (std.mem.indexOf(u8, str, "..")) |dot_idx| {
        const start = try parseCp(str[0..dot_idx]);
        const end = try parseCp(str[dot_idx + 2 ..]);
        return .{ .start = start, .end = end };
    } else {
        const cp = try parseCp(str);
        return .{ .start = cp, .end = cp };
    }
}

test "parseRange" {
    const range = try parseRange("0030..0039");
    try std.testing.expectEqual(0x0030, range.start);
    try std.testing.expectEqual(0x0039, range.end);

    const single = try parseRange("1F600");
    try std.testing.expectEqual(0x1F600, single.start);
    try std.testing.expectEqual(0x1F600, single.end);
}

pub fn trim(line: []const u8) []const u8 {
    if (std.mem.indexOf(u8, line, "#")) |idx| {
        return std.mem.trim(u8, line[0..idx], " \t\r");
    }
    return std.mem.trim(u8, line, " \t\r");
}

const UnicodeData = struct {
    pub fn build(
        comptime fields: []const config.Field,
        comptime fields_is_packed: []const bool,
        comptime input_fields: []const usize,
        comptime build_fields: []const usize,
        allocator: std.mem.Allocator,
        inputs: config.MultiSlice(fields, fields_is_packed, input_fields),
        rows: config.MultiSlice(fields, fields_is_packed, build_fields),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = inputs;

        const Row = config.Row(fields, fields_is_packed, build_fields);
        const default_row: Row = comptime blk: {
            var row: Row = undefined;
            setBuiltField(&row, "name", .empty);
            setBuiltField(&row, "general_category", .other_not_assigned);
            setBuiltField(&row, "canonical_combining_class", 0);
            setBuiltField(&row, "bidi_class", .left_to_right);
            setBuiltField(&row, "decomposition_type", .default);
            setBuiltField(&row, "decomposition_mapping", .same);
            setBuiltField(&row, "numeric_type", .none);
            setOptionalField(&row, "numeric_value_decimal", null);
            setOptionalField(&row, "numeric_value_digit", null);
            setBuiltField(&row, "numeric_value_numeric", .empty);
            setBuiltField(&row, "is_bidi_mirrored", false);
            setBuiltField(&row, "unicode_1_name", .empty);
            setBuiltField(&row, "simple_uppercase_mapping", .same);
            setBuiltField(&row, "simple_lowercase_mapping", .same);
            setBuiltField(&row, "simple_titlecase_mapping", .same);
            break :blk row;
        };

        const file_path = "ucd/UnicodeData.txt";

        // TODO: look for defaults in the Derived Extracted properties files:
        // https://www.unicode.org/reports/tr44/#Derived_Extracted
        //
        // > For nondefault values of properties, if there is any inadvertent
        // mismatch between the primary data files specifying those properties and
        // these lists of extracted properties, the primary data files are taken as
        // definitive. However, for default values of properties, the extracted
        // data files are definitive.

        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 10);
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
                rows.appendAssumeCapacity(range_row orelse default_row);
            }

            if (range_row != null) {
                // We're in a range, so the next entry marks the last, with the same
                // information.
                inlineAssert(std.mem.endsWith(u8, parts.next().?, "Last>"));
                rows.appendAssumeCapacity(range_row.?);
                range_row = null;
                continue;
            }

            const name_str = parts.next().?; // Field 1
            const general_category_str = parts.next().?; // Field 2
            const canonical_combining_class = try std.fmt.parseInt(u8, parts.next().?, 10); // Field 3
            const bidi_class_str = parts.next().?; // Field 4
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

            const bidi_class = bidi_class_map.get(bidi_class_str) orelse blk: {
                std.log.err("Unknown bidi class: {s}", .{bidi_class_str});
                if (!config.is_updating_ucd) {
                    unreachable;
                } else {
                    break :blk .left_to_right;
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

            const row: Row = undefined;
            setField(
                allocator,
                &row,
                "name",
                cp,
                name,
                backing,
                tracking,
            );
            setField(allocator, &row, "name", cp, name, backing, tracking);
            setBuiltField(&row, "general_category", general_category);
            setBuiltField(&row, "canonical_combining_class", canonical_combining_class);
            setBuiltField(&row, "bidi_class", bidi_class);
            setBuiltField(&row, "decomposition_type", decomposition_type);
            setField(
                allocator,
                &row,
                "decomposition_mapping",
                cp,
                decomposition_mapping,
                backing,
                tracking,
            );
            setBuiltField(&row, "numeric_type", numeric_type);
            setOptionalField(&row, "numeric_value_decimal", numeric_value_decimal);
            setOptionalField(&row, "numeric_value_digit", numeric_value_digit);
            setField(
                allocator,
                &row,
                "numeric_value_numeric",
                cp,
                numeric_value_numeric,
                backing,
                tracking,
            );
            setBuiltField(&row, "is_bidi_mirrored", is_bidi_mirrored);
            setField(
                allocator,
                &row,
                "unicode_1_name",
                cp,
                unicode_1_name,
                backing,
                tracking,
            );
            setShiftField(&row, "simple_uppercase_mapping", cp, simple_uppercase_mapping);
            setShiftField(&row, "simple_lowercase_mapping", cp, simple_lowercase_mapping);
            setShiftField(&row, "simple_titlecase_mapping", cp, simple_titlecase_mapping);

            // Handle range entries with "First>" and "Last>"
            if (std.mem.endsWith(u8, name_str, "First>")) {
                range_row = row;
            }

            rows.appendAssumeCapacity(range_row.?);
        }

        // Fill any remaining gaps at the end with default values
        for (rows.len..config.num_code_points) |_| {
            rows.appendAssumeCapacity(default_row);
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

const EmojiVs = struct {
    pub fn build(
        comptime fields: []const config.Field,
        comptime fields_is_packed: []const bool,
        comptime input_fields: []const [:0]const u8,
        comptime build_fields: []const [:0]const u8,
        allocator: std.mem.Allocator,
        inputs: config.FieldArray(fields, fields_is_packed, input_fields),
        rows: config.FieldArray(fields, fields_is_packed, build_fields),
        backing: anytype,
        tracking: anytype,
    ) !void {
        _ = inputs;
        _ = backing;
        _ = tracking;

        const file_path = "ucd/emoji/emoji-variation-sequences.txt";

        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
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
