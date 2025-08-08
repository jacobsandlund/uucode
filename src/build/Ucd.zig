//! This File is Layer 1 of the architecture (see /AGENT.md), processing
//! the Unicode Character Database (UCD) files (see https://www.unicode.org/reports/tr44/).

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const config = @import("config.zig");

const table_configs = &@import("build_config").tables;

const ucd_config_fields = blk: {
    var fields: [config.default.fields.len]config.Field = undefined;
    var i: usize = 0;
    var input_var_lens: [config.default.fields.len][]const u8 = undefined;
    var ivl_i: usize = 0;

    for (table_configs) |tc| {
        table_fields: for (tc.fields) |f| {
            // If a field isn't in `default` it's an extension field
            if (!config.default.hasField(f.name)) continue :table_fields;

            if (f.kind() == .var_len) {
                for (fields[0..i]) |existing| {
                    if (std.mem.eql(u8, existing.name, f.name)) {
                        @compileError("Variable length field '" ++ f.name ++ "' already exists in another table, but this is not supported.");
                    }
                }
            }

            fields[i] = f;
            i += 1;
        }

        for (tc.extensions) |x| {
            loop_inputs: for (x.inputs) |input| {
                for (config.default.fields) |f| {
                    if (f.kind() == .var_len and std.mem.eql(u8, f.name, input)) {
                        input_var_lens[ivl_i] = input;
                        ivl_i += 1;
                        continue :loop_inputs;
                    }
                }
            }
        }
    }

    default_fields: for (config.default.fields) |f| {
        @setEvalBranchQuota(5_000);
        for (fields[0..i]) |existing| {
            if (std.mem.eql(u8, existing.name, f.name)) {
                continue :default_fields;
            }
        }

        if (f.kind() == .var_len and
            for (input_var_lens[0..ivl_i]) |input| {
                if (std.mem.eql(u8, input, f.name)) {
                    break true;
                }
            } else false)
        {
            // When varlen fields aren't present, we configure this so the
            // values get thrown away.
            fields[i] = f.override(.{
                .embedded_len = 0,
                .max_offset = 0,
            });
        } else {
            fields[i] = f;
        }

        i += 1;
    }

    break :blk fields;
};

const ucd_config = blk: {
    if (config.is_updating_ucd) {
        break :blk config.updating_ucd;
    }

    break :blk config.Table{
        .fields = &ucd_config_fields,
    };
};

const UnicodeData = types.UnicodeData(ucd_config);
const CaseFolding = types.CaseFolding(ucd_config);
const SpecialCasing = types.SpecialCasing(ucd_config);

unicode_data: []UnicodeData,
case_folding: std.AutoHashMapUnmanaged(u21, CaseFolding),
special_casing: std.AutoHashMapUnmanaged(u21, SpecialCasing),
derived_core_properties: std.AutoHashMapUnmanaged(u21, types.DerivedCoreProperties),
east_asian_width: std.AutoHashMapUnmanaged(u21, types.EastAsianWidth),
original_grapheme_break: std.AutoHashMapUnmanaged(u21, types.OriginalGraphemeBreak),
emoji_data: std.AutoHashMapUnmanaged(u21, types.EmojiData),
blocks: std.AutoHashMapUnmanaged(u21, types.Block),
backing: *BackingArrays,

const Self = @This();

const VarLenData = struct {
    const name = @FieldType(UnicodeData, "name");
    const decomposition_mapping = @FieldType(UnicodeData, "decomposition_mapping");
    const numeric_value_numeric = @FieldType(UnicodeData, "numeric_value_numeric");
    const unicode_1_name = @FieldType(UnicodeData, "unicode_1_name");
    const case_folding_full = @FieldType(CaseFolding, "case_folding_full");
    const special_lowercase_mapping = @FieldType(SpecialCasing, "special_lowercase_mapping");
    const special_titlecase_mapping = @FieldType(SpecialCasing, "special_titlecase_mapping");
    const special_uppercase_mapping = @FieldType(SpecialCasing, "special_uppercase_mapping");
    const special_casing_condition = @FieldType(SpecialCasing, "special_casing_condition");
};

const ShiftData = struct {
    const simple_uppercase_mapping = @FieldType(UnicodeData, "simple_uppercase_mapping");
    const simple_lowercase_mapping = @FieldType(UnicodeData, "simple_lowercase_mapping");
    const simple_titlecase_mapping = @FieldType(UnicodeData, "simple_titlecase_mapping");
    const case_folding_simple = @FieldType(CaseFolding, "case_folding_simple");
    const case_folding_turkish = @FieldType(CaseFolding, "case_folding_turkish");
};

const BackingArrays = struct {
    name: VarLenData.name.BackingArray,
    decomposition_mapping: VarLenData.decomposition_mapping.BackingArray,
    numeric_value_numeric: VarLenData.numeric_value_numeric.BackingArray,
    unicode_1_name: VarLenData.unicode_1_name.BackingArray,
    case_folding_full: VarLenData.case_folding_full.BackingArray,
    special_lowercase_mapping: VarLenData.special_lowercase_mapping.BackingArray,
    special_titlecase_mapping: VarLenData.special_titlecase_mapping.BackingArray,
    special_uppercase_mapping: VarLenData.special_uppercase_mapping.BackingArray,
    special_casing_condition: VarLenData.special_casing_condition.BackingArray,
};

const OffsetMaps = struct {
    name: VarLenData.name.OffsetMap,
    decomposition_mapping: VarLenData.decomposition_mapping.OffsetMap,
    numeric_value_numeric: VarLenData.numeric_value_numeric.OffsetMap,
    unicode_1_name: VarLenData.unicode_1_name.OffsetMap,
    case_folding_full: VarLenData.case_folding_full.OffsetMap,
    special_lowercase_mapping: VarLenData.special_lowercase_mapping.OffsetMap,
    special_titlecase_mapping: VarLenData.special_titlecase_mapping.OffsetMap,
    special_uppercase_mapping: VarLenData.special_uppercase_mapping.OffsetMap,
    special_casing_condition: VarLenData.special_casing_condition.OffsetMap,
};

const LenTracking = struct {
    name: VarLenData.name.LenTracking,
    decomposition_mapping: VarLenData.decomposition_mapping.LenTracking,
    numeric_value_numeric: VarLenData.numeric_value_numeric.LenTracking,
    unicode_1_name: VarLenData.unicode_1_name.LenTracking,
    case_folding_full: VarLenData.case_folding_full.LenTracking,
    special_lowercase_mapping: VarLenData.special_lowercase_mapping.LenTracking,
    special_titlecase_mapping: VarLenData.special_titlecase_mapping.LenTracking,
    special_uppercase_mapping: VarLenData.special_uppercase_mapping.LenTracking,
    special_casing_condition: VarLenData.special_casing_condition.LenTracking,
};

const ShiftTracking = struct {
    simple_uppercase_mapping: types.ShiftTracking = .{},
    simple_lowercase_mapping: types.ShiftTracking = .{},
    simple_titlecase_mapping: types.ShiftTracking = .{},
    case_folding_simple: types.ShiftTracking = .{},
    case_folding_turkish: types.ShiftTracking = .{},
};

pub fn init(allocator: std.mem.Allocator) !Self {
    const start = try std.time.Instant.now();

    var ucd = Self{
        .unicode_data = undefined,
        .case_folding = .{},
        .special_casing = .{},
        .derived_core_properties = .{},
        .east_asian_width = .{},
        .original_grapheme_break = .{},
        .emoji_data = .{},
        .blocks = .{},
        .backing = undefined,
    };

    ucd.unicode_data = try allocator.alloc(UnicodeData, config.code_point_range_end);
    errdefer allocator.free(ucd.unicode_data);

    ucd.backing = blk: {
        const b: *BackingArrays = try allocator.create(BackingArrays);
        b.* = std.mem.zeroInit(BackingArrays, .{});

        break :blk b;
    };
    errdefer allocator.destroy(ucd.backing);

    var maps = blk: {
        var m: OffsetMaps = undefined;
        inline for (@typeInfo(OffsetMaps).@"struct".fields) |field| {
            @field(m, field.name) = .empty;
        }
        break :blk m;
    };
    defer {
        inline for (@typeInfo(OffsetMaps).@"struct".fields) |field| {
            @field(maps, field.name).deinit(allocator);
        }
    }

    var len_tracking = blk: {
        var lt: LenTracking = undefined;
        inline for (@typeInfo(LenTracking).@"struct".fields) |field| {
            const field_info = @typeInfo(field.type);
            @field(lt, field.name) = [_]@field(VarLenData, field.name).Offset{0} ** field_info.array.len;
        }

        break :blk lt;
    };

    var shift_tracking: ShiftTracking = .{};

    try parseUnicodeData(allocator, &ucd, &maps, &len_tracking, &shift_tracking);
    try parseCaseFolding(allocator, &ucd, &maps, &len_tracking, &shift_tracking);
    try parseSpecialCasing(allocator, &ucd, &maps, &len_tracking);
    try parseDerivedCoreProperties(allocator, &ucd.derived_core_properties);
    try parseEastAsianWidth(allocator, &ucd.east_asian_width);
    try parseGraphemeBreakProperty(allocator, &ucd.original_grapheme_break);
    try parseEmojiData(allocator, &ucd.emoji_data);
    try parseBlocks(allocator, &ucd.blocks);

    if (config.is_updating_ucd) {
        const fields = [_]config.Field.Runtime{
            VarLenData.name.minBitsConfig(
                &ucd.backing.name,
                &len_tracking.name,
            ),
            VarLenData.decomposition_mapping.minBitsConfig(
                &ucd.backing.decomposition_mapping,
                &len_tracking.decomposition_mapping,
            ),
            VarLenData.numeric_value_numeric.minBitsConfig(
                &ucd.backing.numeric_value_numeric,
                &len_tracking.numeric_value_numeric,
            ),
            VarLenData.unicode_1_name.minBitsConfig(
                &ucd.backing.unicode_1_name,
                &len_tracking.unicode_1_name,
            ),
            VarLenData.case_folding_full.minBitsConfig(
                &ucd.backing.case_folding_full,
                &len_tracking.case_folding_full,
            ),
            VarLenData.special_lowercase_mapping.minBitsConfig(
                &ucd.backing.special_lowercase_mapping,
                &len_tracking.special_lowercase_mapping,
            ),
            VarLenData.special_titlecase_mapping.minBitsConfig(
                &ucd.backing.special_titlecase_mapping,
                &len_tracking.special_titlecase_mapping,
            ),
            VarLenData.special_uppercase_mapping.minBitsConfig(
                &ucd.backing.special_uppercase_mapping,
                &len_tracking.special_uppercase_mapping,
            ),
            VarLenData.special_casing_condition.minBitsConfig(
                &ucd.backing.special_casing_condition,
                &len_tracking.special_casing_condition,
            ),
            ShiftData.simple_uppercase_mapping.minBitsConfig(
                &shift_tracking.simple_uppercase_mapping,
            ),
            ShiftData.simple_lowercase_mapping.minBitsConfig(
                &shift_tracking.simple_lowercase_mapping,
            ),
            ShiftData.simple_titlecase_mapping.minBitsConfig(
                &shift_tracking.simple_titlecase_mapping,
            ),
            ShiftData.case_folding_simple.minBitsConfig(
                &shift_tracking.case_folding_simple,
            ),
            ShiftData.case_folding_turkish.minBitsConfig(
                &shift_tracking.case_folding_turkish,
            ),
        };

        const defaults = comptime [_]config.Field.Runtime{
            config.default.field("name").runtime(.{}),
            config.default.field("decomposition_mapping").runtime(.{}),
            config.default.field("numeric_value_numeric").runtime(.{}),
            config.default.field("unicode_1_name").runtime(.{}),
            config.default.field("case_folding_full").runtime(.{}),
            config.default.field("special_lowercase_mapping").runtime(.{}),
            config.default.field("special_titlecase_mapping").runtime(.{}),
            config.default.field("special_uppercase_mapping").runtime(.{}),
            config.default.field("special_casing_condition").runtime(.{}),
            config.default.field("simple_uppercase_mapping").runtime(.{}),
            config.default.field("simple_lowercase_mapping").runtime(.{}),
            config.default.field("simple_titlecase_mapping").runtime(.{}),
            config.default.field("case_folding_simple").runtime(.{}),
            config.default.field("case_folding_turkish").runtime(.{}),
        };

        for (fields, defaults) |f, d| {
            if (!d.eql(f)) {
                const writer = std.io.getStdErr().writer();
                try writer.writeAll(
                    \\
                    \\ Update default config in `config.zig` with the correct field config:
                    \\
                    \\
                );
                try f.write(writer);
            }
        }
    }

    const end = try std.time.Instant.now();
    std.log.debug("Ucd init time: {d}ms\n", .{end.since(start) / std.time.ns_per_ms});

    return ucd;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.unicode_data);
    self.case_folding.deinit(allocator);
    self.special_casing.deinit(allocator);
    self.derived_core_properties.deinit(allocator);
    self.east_asian_width.deinit(allocator);
    self.original_grapheme_break.deinit(allocator);
    self.emoji_data.deinit(allocator);
    self.blocks.deinit(allocator);
    allocator.destroy(self.backing);
}

fn parseCodePoint(str: []const u8) !u21 {
    return std.fmt.parseInt(u21, str, 16);
}

fn parseCodePointRange(str: []const u8) !struct { start: u21, end: u21 } {
    if (std.mem.indexOf(u8, str, "..")) |dot_idx| {
        const start = try parseCodePoint(str[0..dot_idx]);
        const end = try parseCodePoint(str[dot_idx + 2 ..]);
        return .{ .start = start, .end = end };
    } else {
        const cp = try parseCodePoint(str);
        return .{ .start = cp, .end = cp };
    }
}

fn stripComment(line: []const u8) []const u8 {
    if (std.mem.indexOf(u8, line, "#")) |idx| {
        return std.mem.trim(u8, line[0..idx], " \t");
    }
    return std.mem.trim(u8, line, " \t");
}

fn parseUnicodeData(
    allocator: std.mem.Allocator,
    ucd: *Self,
    maps: *OffsetMaps,
    len_tracking: *LenTracking,
    shift_tracking: *ShiftTracking,
) !void {
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
    var next_cp: u21 = 0x0000;
    const default_data = UnicodeData{
        .name = .empty,
        .general_category = types.GeneralCategory.other_not_assigned,
        .canonical_combining_class = 0,
        .bidi_class = types.BidiClass.left_to_right,
        .decomposition_type = types.DecompositionType.default,
        .decomposition_mapping = .empty,
        .numeric_type = types.NumericType.none,
        .numeric_value_decimal = .null,
        .numeric_value_digit = .null,
        .numeric_value_numeric = .empty,
        .is_bidi_mirrored = false,
        .unicode_1_name = .empty,
        .simple_uppercase_mapping = .null,
        .simple_lowercase_mapping = .null,
        .simple_titlecase_mapping = .null,
    };
    var range_data: ?UnicodeData = null;

    while (lines.next()) |line| : (next_cp += 1) {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = parts.next().?;
        const cp = try parseCodePoint(cp_str);

        while (cp > next_cp) : (next_cp += 1) {
            // Fill any gaps or ranges
            ucd.unicode_data[next_cp] = range_data orelse default_data;
        }

        if (range_data != null) {
            // We're in a range, so the next entry marks the last, with the same
            // information.
            std.debug.assert(std.mem.endsWith(u8, parts.next().?, "Last>"));
            ucd.unicode_data[next_cp] = range_data.?;
            range_data = null;
            continue;
        }

        const name_str = parts.next().?; // Field 1
        const general_category_str = parts.next().?; // Field 2
        const canonical_combining_class = std.fmt.parseInt(u8, parts.next().?, 10) catch 0; // Field 3
        const bidi_class_str = parts.next().?; // Field 4
        const decomposition_str = parts.next().?; // Field 5: Combined type and mapping
        const numeric_decimal_str = parts.next().?; // Field 6
        const numeric_digit_str = parts.next().?; // Field 7
        const numeric_numeric_str = parts.next().?; // Field 8
        const is_bidi_mirrored = std.mem.eql(u8, parts.next().?, "Y"); // Field 9
        const unicode_1_name = parts.next().?; // Field 10
        _ = parts.next().?; // Field 11: Obsolete ISO_Comment
        const simple_uppercase_mapping_str = parts.next().?; // Field 12
        const simple_lowercase_mapping_str = parts.next().?; // Field 13
        const simple_titlecase_mapping_str = parts.next().?; // Field 14

        const name = if (std.mem.endsWith(u8, name_str, "First>")) name_str["<".len..(name_str.len - ", First>".len)] else name_str;
        const general_category = general_category_map.get(general_category_str) orelse {
            std.log.err("Unknown general category: {s}", .{general_category_str});
            unreachable;
        };

        const bidi_class = bidi_class_map.get(bidi_class_str) orelse {
            std.log.err("Unknown bidi class: {s}", .{bidi_class_str});
            unreachable;
        };

        const simple_uppercase_mapping = if (simple_uppercase_mapping_str.len == 0) null else try parseCodePoint(simple_uppercase_mapping_str);
        const simple_lowercase_mapping = if (simple_lowercase_mapping_str.len == 0) null else try parseCodePoint(simple_lowercase_mapping_str);
        const simple_titlecase_mapping = if (simple_titlecase_mapping_str.len == 0) null else try parseCodePoint(simple_titlecase_mapping_str);

        // Parse decomposition type and mapping from single field
        // Default: character decomposes to itself (field 5 empty)
        var decomposition_type = types.DecompositionType.default;
        var decomposition_mapping: VarLenData.decomposition_mapping = .empty;

        if (decomposition_str.len > 0) {
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
                decomposition_type = std.meta.stringToEnum(types.DecompositionType, type_str) orelse {
                    std.log.err("Unknown decomposition type: {s}", .{type_str});
                    unreachable;
                };
                mapping_str = std.mem.trim(u8, decomposition_str[end_bracket + 1 ..], " \t");
            }

            // Parse code points from mapping string
            if (mapping_str.len > 0) {
                var mapping_parts = std.mem.splitScalar(u8, mapping_str, ' ');
                var temp_mapping: [18]u21 = undefined; // Unicode spec says max 18
                var mapping_len: u8 = 0;

                while (mapping_parts.next()) |part| {
                    if (part.len == 0) continue;
                    if (mapping_len >= 18) {
                        std.log.err("Decomposition mapping too long at {X}: {s}", .{ cp, decomposition_str });
                        unreachable;
                    }
                    temp_mapping[mapping_len] = try parseCodePoint(part);
                    mapping_len += 1;
                }

                decomposition_mapping = try .fromSlice(
                    allocator,
                    &ucd.backing.decomposition_mapping,
                    &maps.decomposition_mapping,
                    &len_tracking.decomposition_mapping,
                    temp_mapping[0..mapping_len],
                );
            }
        }

        // Determine numeric type and parse values based on which field has a value
        var numeric_type = types.NumericType.none;
        var numeric_value_decimal: ?u4 = null;
        var numeric_value_digit: ?u4 = null;
        var numeric_value_numeric: VarLenData.numeric_value_numeric = .empty;

        if (numeric_decimal_str.len > 0) {
            numeric_type = types.NumericType.decimal;
            numeric_value_decimal = std.fmt.parseInt(u4, numeric_decimal_str, 10) catch |err| {
                std.log.err("Invalid decimal numeric value '{s}' at codepoint {X}: {}", .{ numeric_decimal_str, cp, err });
                unreachable;
            };
        } else if (numeric_digit_str.len > 0) {
            numeric_type = types.NumericType.digit;
            numeric_value_digit = std.fmt.parseInt(u4, numeric_digit_str, 10) catch |err| {
                std.log.err("Invalid digit numeric value '{s}' at codepoint {X}: {}", .{ numeric_digit_str, cp, err });
                unreachable;
            };
        } else if (numeric_numeric_str.len > 0) {
            numeric_type = types.NumericType.numeric;
            numeric_value_numeric = try .fromSlice(
                allocator,
                &ucd.backing.numeric_value_numeric,
                &maps.numeric_value_numeric,
                &len_tracking.numeric_value_numeric,
                numeric_numeric_str,
            );
        }

        const unicode_data = UnicodeData{
            .name = try .fromSlice(
                allocator,
                &ucd.backing.name,
                &maps.name,
                &len_tracking.name,
                name,
            ),
            .general_category = general_category,
            .canonical_combining_class = canonical_combining_class,
            .bidi_class = bidi_class,
            .decomposition_type = decomposition_type,
            .decomposition_mapping = decomposition_mapping,
            .numeric_type = numeric_type,
            .numeric_value_decimal = .init(numeric_value_decimal),
            .numeric_value_digit = .init(numeric_value_digit),
            .numeric_value_numeric = numeric_value_numeric,
            .is_bidi_mirrored = is_bidi_mirrored,
            .unicode_1_name = try .fromSlice(
                allocator,
                &ucd.backing.unicode_1_name,
                &maps.unicode_1_name,
                &len_tracking.unicode_1_name,
                unicode_1_name,
            ),
            .simple_uppercase_mapping = .initOptionalTracked(
                cp,
                simple_uppercase_mapping,
                &shift_tracking.simple_uppercase_mapping,
            ),
            .simple_lowercase_mapping = .initOptionalTracked(
                cp,
                simple_lowercase_mapping,
                &shift_tracking.simple_lowercase_mapping,
            ),
            .simple_titlecase_mapping = .initOptionalTracked(
                cp,
                simple_titlecase_mapping,
                &shift_tracking.simple_titlecase_mapping,
            ),
        };

        // Handle range entries with "First>" and "Last>"
        if (std.mem.endsWith(u8, name, "First>")) {
            range_data = unicode_data;
        }

        ucd.unicode_data[cp] = unicode_data;
    }

    // Fill any remaining gaps at the end with default values
    while (next_cp < config.code_point_range_end) : (next_cp += 1) {
        ucd.unicode_data[next_cp] = default_data;
    }
}

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

fn parseCaseFolding(
    allocator: std.mem.Allocator,
    ucd: *Self,
    maps: *OffsetMaps,
    len_tracking: *LenTracking,
    shift_tracking: *ShiftTracking,
) !void {
    const file_path = "ucd/CaseFolding.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const cp = try parseCodePoint(cp_str);

        const status_str = std.mem.trim(u8, parts.next().?, " \t");
        const status = if (status_str.len > 0) status_str[0] else 0;

        const mapping_str = std.mem.trim(u8, parts.next() orelse "", " \t");
        var mapping_parts = std.mem.splitScalar(u8, mapping_str, ' ');

        var mapping: [3]u21 = undefined;
        var mapping_len: u2 = 0;

        while (mapping_parts.next()) |part| {
            if (part.len == 0) continue;
            const mapped_cp = try parseCodePoint(part);
            if (mapping_len >= 3) {
                std.log.err("CaseFolding mapping has more than 3 code points at codepoint {X}: {s}", .{ cp, mapping_str });
                unreachable;
            }
            mapping[mapping_len] = mapped_cp;
            mapping_len += 1;
        }

        const result = try ucd.case_folding.getOrPut(allocator, cp);
        if (!result.found_existing) {
            result.value_ptr.* = CaseFolding{
                .case_folding_simple = .no_shift,
                .case_folding_turkish = .no_shift,
                .case_folding_full = undefined,
            };
        }

        switch (status) {
            'S', 'C' => {
                std.debug.assert(mapping_len == 1);
                result.value_ptr.case_folding_simple = .initTracked(
                    cp,
                    mapping[0],
                    &shift_tracking.case_folding_simple,
                );
            },
            'F' => {
                std.debug.assert(mapping_len > 1);
                result.value_ptr.case_folding_full = try .fromSlice(
                    allocator,
                    &ucd.backing.case_folding_full,
                    &maps.case_folding_full,
                    &len_tracking.case_folding_full,
                    mapping[0..mapping_len],
                );
            },
            'T' => {
                std.debug.assert(mapping_len == 1);
                result.value_ptr.case_folding_turkish = .initTracked(
                    cp,
                    mapping[0],
                    &shift_tracking.case_folding_turkish,
                );
            },
            else => unreachable,
        }
    }
}

fn parseSpecialCasing(
    allocator: std.mem.Allocator,
    ucd: *Self,
    maps: *OffsetMaps,
    len_tracking: *LenTracking,
) !void {
    const file_path = "ucd/SpecialCasing.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const cp = try parseCodePoint(cp_str);

        const lower_str = std.mem.trim(u8, parts.next().?, " \t");
        const title_str = std.mem.trim(u8, parts.next().?, " \t");
        const upper_str = std.mem.trim(u8, parts.next().?, " \t");

        // Parse the optional condition list
        var conditions: [2]types.SpecialCasingCondition = undefined;
        var conditions_len: u8 = 0;
        if (parts.next()) |condition_str| {
            const trimmed_conditions = std.mem.trim(u8, condition_str, " \t");
            if (trimmed_conditions.len > 0) {
                var condition_parts = std.mem.splitScalar(u8, trimmed_conditions, ' ');
                while (condition_parts.next()) |condition_part| {
                    const trimmed_condition = std.mem.trim(u8, condition_part, " \t");
                    if (trimmed_condition.len == 0) continue;
                    if (conditions_len >= 2) {
                        std.log.err("SpecialCasing has more than 2 conditions at codepoint {X}: {s}", .{ cp, trimmed_conditions });
                        unreachable;
                    }
                    const condition = special_casing_condition_map.get(trimmed_condition) orelse types.SpecialCasingCondition.none;
                    conditions[conditions_len] = condition;
                    conditions_len += 1;
                }
            }
        }

        // Parse mappings
        var lower_mapping: [3]u21 = undefined;
        var lower_mapping_len: u8 = 0;
        var lower_parts = std.mem.splitScalar(u8, lower_str, ' ');
        while (lower_parts.next()) |part| {
            if (part.len == 0) continue;
            if (lower_mapping_len >= 3) {
                std.log.err("SpecialCasing lower mapping has more than 3 code points at codepoint {X}: {s}", .{ cp, lower_str });
                unreachable;
            }
            lower_mapping[lower_mapping_len] = try parseCodePoint(part);
            lower_mapping_len += 1;
        }

        var title_mapping: [3]u21 = undefined;
        var title_mapping_len: u8 = 0;
        var title_parts = std.mem.splitScalar(u8, title_str, ' ');
        while (title_parts.next()) |part| {
            if (part.len == 0) continue;
            if (title_mapping_len >= 3) {
                std.log.err("SpecialCasing title mapping has more than 3 code points at codepoint {X}: {s}", .{ cp, title_str });
                unreachable;
            }
            title_mapping[title_mapping_len] = try parseCodePoint(part);
            title_mapping_len += 1;
        }

        var upper_mapping: [3]u21 = undefined;
        var upper_mapping_len: u8 = 0;
        var upper_parts = std.mem.splitScalar(u8, upper_str, ' ');
        while (upper_parts.next()) |part| {
            if (part.len == 0) continue;
            if (upper_mapping_len >= 3) {
                std.log.err("SpecialCasing upper mapping has more than 3 code points at codepoint {X}: {s}", .{ cp, upper_str });
                unreachable;
            }
            upper_mapping[upper_mapping_len] = try parseCodePoint(part);
            upper_mapping_len += 1;
        }

        try ucd.special_casing.put(allocator, cp, .{
            .special_lowercase_mapping = try .fromSlice(
                allocator,
                &ucd.backing.special_lowercase_mapping,
                &maps.special_lowercase_mapping,
                &len_tracking.special_lowercase_mapping,
                lower_mapping[0..lower_mapping_len],
            ),
            .special_titlecase_mapping = try .fromSlice(
                allocator,
                &ucd.backing.special_titlecase_mapping,
                &maps.special_titlecase_mapping,
                &len_tracking.special_titlecase_mapping,
                title_mapping[0..title_mapping_len],
            ),
            .special_uppercase_mapping = try .fromSlice(
                allocator,
                &ucd.backing.special_uppercase_mapping,
                &maps.special_uppercase_mapping,
                &len_tracking.special_uppercase_mapping,
                upper_mapping[0..upper_mapping_len],
            ),
            .special_casing_condition = try .fromSlice(
                allocator,
                &ucd.backing.special_casing_condition,
                &maps.special_casing_condition,
                &len_tracking.special_casing_condition,
                conditions[0..conditions_len],
            ),
        });
    }
}

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

fn parseDerivedCoreProperties(
    allocator: std.mem.Allocator,
    map: *std.AutoHashMapUnmanaged(u21, types.DerivedCoreProperties),
) !void {
    const file_path = "ucd/DerivedCoreProperties.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 2);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const property = std.mem.trim(u8, parts.next().?, " \t");
        const value_str = if (parts.next()) |v| std.mem.trim(u8, v, " \t") else "";

        const range = try parseCodePointRange(cp_str);

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            const result = try map.getOrPut(allocator, cp);
            if (!result.found_existing) {
                result.value_ptr.* = types.DerivedCoreProperties{};
            }

            if (std.mem.eql(u8, property, "Math")) {
                result.value_ptr.is_math = true;
            } else if (std.mem.eql(u8, property, "Alphabetic")) {
                result.value_ptr.is_alphabetic = true;
            } else if (std.mem.eql(u8, property, "Lowercase")) {
                result.value_ptr.is_lowercase = true;
            } else if (std.mem.eql(u8, property, "Uppercase")) {
                result.value_ptr.is_uppercase = true;
            } else if (std.mem.eql(u8, property, "Cased")) {
                result.value_ptr.is_cased = true;
            } else if (std.mem.eql(u8, property, "Case_Ignorable")) {
                result.value_ptr.is_case_ignorable = true;
            } else if (std.mem.eql(u8, property, "Changes_When_Lowercased")) {
                result.value_ptr.changes_when_lowercased = true;
            } else if (std.mem.eql(u8, property, "Changes_When_Uppercased")) {
                result.value_ptr.changes_when_uppercased = true;
            } else if (std.mem.eql(u8, property, "Changes_When_Titlecased")) {
                result.value_ptr.changes_when_titlecased = true;
            } else if (std.mem.eql(u8, property, "Changes_When_Casefolded")) {
                result.value_ptr.changes_when_casefolded = true;
            } else if (std.mem.eql(u8, property, "Changes_When_Casemapped")) {
                result.value_ptr.changes_when_casemapped = true;
            } else if (std.mem.eql(u8, property, "ID_Start")) {
                result.value_ptr.is_id_start = true;
            } else if (std.mem.eql(u8, property, "ID_Continue")) {
                result.value_ptr.is_id_continue = true;
            } else if (std.mem.eql(u8, property, "XID_Start")) {
                result.value_ptr.is_xid_start = true;
            } else if (std.mem.eql(u8, property, "XID_Continue")) {
                result.value_ptr.is_xid_continue = true;
            } else if (std.mem.eql(u8, property, "Default_Ignorable_Code_Point")) {
                result.value_ptr.is_default_ignorable_code_point = true;
            } else if (std.mem.eql(u8, property, "Grapheme_Extend")) {
                result.value_ptr.is_grapheme_extend = true;
            } else if (std.mem.eql(u8, property, "Grapheme_Base")) {
                result.value_ptr.is_grapheme_base = true;
            } else if (std.mem.eql(u8, property, "Grapheme_Link")) {
                result.value_ptr.is_grapheme_link = true;
            } else if (std.mem.eql(u8, property, "InCB")) {
                if (std.mem.eql(u8, value_str, "Linker")) {
                    result.value_ptr.indic_conjunct_break = .linker;
                } else if (std.mem.eql(u8, value_str, "Consonant")) {
                    result.value_ptr.indic_conjunct_break = .consonant;
                } else if (std.mem.eql(u8, value_str, "Extend")) {
                    result.value_ptr.indic_conjunct_break = .extend;
                } else {
                    std.log.err("Unknown InCB value: {s}", .{value_str});
                    unreachable;
                }
            } else {
                std.log.err("Unknown DerivedCoreProperties property: {s}", .{property});
                unreachable;
            }
        }
    }
}

fn parseEastAsianWidth(
    allocator: std.mem.Allocator,
    map: *std.AutoHashMapUnmanaged(u21, types.EastAsianWidth),
) !void {
    const file_path = "ucd/extracted/DerivedEastAsianWidth.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len == 0) continue;

        // Handle @missing directives first
        if (std.mem.startsWith(u8, trimmed, "# @missing:")) {
            const missing_line = trimmed["# @missing:".len..];
            var parts = std.mem.splitScalar(u8, missing_line, ';');
            const cp_str = std.mem.trim(u8, parts.next().?, " \t");
            const width_str = std.mem.trim(u8, parts.next().?, " \t");

            const range = try parseCodePointRange(cp_str);

            // Skip `neutral` as it's the default
            if (std.mem.eql(u8, width_str, "Neutral")) {
                continue;
            }

            if (!std.mem.eql(u8, width_str, "Wide")) {
                std.log.err("Unknown @missing EastAsianWidth value: {s}", .{width_str});
                unreachable;
            }

            var cp: u21 = range.start;
            while (cp <= range.end) : (cp += 1) {
                try map.put(allocator, cp, .wide);
            }
            continue;
        }

        // Handle regular entries
        const data_line = stripComment(trimmed);
        if (data_line.len == 0) continue;

        var parts = std.mem.splitScalar(u8, data_line, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const width_str = std.mem.trim(u8, parts.next().?, " \t");

        const range = try parseCodePointRange(cp_str);

        const width = if (std.mem.eql(u8, width_str, "F"))
            types.EastAsianWidth.fullwidth
        else if (std.mem.eql(u8, width_str, "H"))
            types.EastAsianWidth.halfwidth
        else if (std.mem.eql(u8, width_str, "W"))
            types.EastAsianWidth.wide
        else if (std.mem.eql(u8, width_str, "Na"))
            types.EastAsianWidth.narrow
        else if (std.mem.eql(u8, width_str, "A"))
            types.EastAsianWidth.ambiguous
        else if (std.mem.eql(u8, width_str, "N"))
            types.EastAsianWidth.neutral
        else {
            std.log.err("Unknown EastAsianWidth value: {s}", .{width_str});
            unreachable;
        };

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(allocator, cp, width);
        }
    }
}

fn parseGraphemeBreakProperty(
    allocator: std.mem.Allocator,
    map: *std.AutoHashMapUnmanaged(u21, types.OriginalGraphemeBreak),
) !void {
    const file_path = "ucd/auxiliary/GraphemeBreakProperty.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const prop_str = std.mem.trim(u8, parts.next().?, " \t");

        const range = try parseCodePointRange(cp_str);

        const prop = if (std.mem.eql(u8, prop_str, "Prepend"))
            types.OriginalGraphemeBreak.prepend
        else if (std.mem.eql(u8, prop_str, "CR"))
            types.OriginalGraphemeBreak.cr
        else if (std.mem.eql(u8, prop_str, "LF"))
            types.OriginalGraphemeBreak.lf
        else if (std.mem.eql(u8, prop_str, "Control"))
            types.OriginalGraphemeBreak.control
        else if (std.mem.eql(u8, prop_str, "Extend"))
            types.OriginalGraphemeBreak.extend
        else if (std.mem.eql(u8, prop_str, "Regional_Indicator"))
            types.OriginalGraphemeBreak.regional_indicator
        else if (std.mem.eql(u8, prop_str, "SpacingMark"))
            types.OriginalGraphemeBreak.spacingmark
        else if (std.mem.eql(u8, prop_str, "L"))
            types.OriginalGraphemeBreak.l
        else if (std.mem.eql(u8, prop_str, "V"))
            types.OriginalGraphemeBreak.v
        else if (std.mem.eql(u8, prop_str, "T"))
            types.OriginalGraphemeBreak.t
        else if (std.mem.eql(u8, prop_str, "LV"))
            types.OriginalGraphemeBreak.lv
        else if (std.mem.eql(u8, prop_str, "LVT"))
            types.OriginalGraphemeBreak.lvt
        else if (std.mem.eql(u8, prop_str, "ZWJ"))
            types.OriginalGraphemeBreak.zwj
        else
            types.OriginalGraphemeBreak.other;

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(allocator, cp, prop);
        }
    }
}

fn parseEmojiData(
    allocator: std.mem.Allocator,
    map: *std.AutoHashMapUnmanaged(u21, types.EmojiData),
) !void {
    const file_path = "ucd/emoji/emoji-data.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const prop_str = std.mem.trim(u8, parts.next().?, " \t");

        const range = try parseCodePointRange(cp_str);

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            const result = try map.getOrPut(allocator, cp);
            if (!result.found_existing) {
                result.value_ptr.* = types.EmojiData{};
            }

            if (std.mem.eql(u8, prop_str, "Emoji")) {
                result.value_ptr.is_emoji = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Presentation")) {
                result.value_ptr.has_emoji_presentation = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Modifier")) {
                result.value_ptr.is_emoji_modifier = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Modifier_Base")) {
                result.value_ptr.is_emoji_modifier_base = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Component")) {
                result.value_ptr.is_emoji_component = true;
            } else if (std.mem.eql(u8, prop_str, "Extended_Pictographic")) {
                result.value_ptr.is_extended_pictographic = true;
            } else {
                std.log.err("Unknown EmojiData property: {s}", .{prop_str});
                unreachable;
            }
        }
    }
}

test "parse code point" {
    try std.testing.expectEqual(@as(u21, 0x0000), try parseCodePoint("0000"));
    try std.testing.expectEqual(@as(u21, 0x1F600), try parseCodePoint("1F600"));
}

test "parse code point range" {
    const range = try parseCodePointRange("0030..0039");
    try std.testing.expectEqual(@as(u21, 0x0030), range.start);
    try std.testing.expectEqual(@as(u21, 0x0039), range.end);

    const single = try parseCodePointRange("1F600");
    try std.testing.expectEqual(@as(u21, 0x1F600), single.start);
    try std.testing.expectEqual(@as(u21, 0x1F600), single.end);
}

fn parseBlocks(
    allocator: std.mem.Allocator,
    map: *std.AutoHashMapUnmanaged(u21, types.Block),
) !void {
    const file_path = "ucd/Blocks.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next().?, " \t");
        const block_name = std.mem.trim(u8, parts.next().?, " \t");

        const range = try parseCodePointRange(cp_str);

        const block = block_name_map.get(block_name) orelse {
            std.log.err("Unknown block name: {s}", .{block_name});
            unreachable;
        };

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(allocator, cp, block);
        }
    }
}

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
    .{ "Sharada", .sharada },
    .{ "Shavian", .shavian },
    .{ "Shorthand Format Controls", .shorthand_format_controls },
    .{ "Siddham", .siddham },
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
    .{ "Takri", .takri },
    .{ "Tamil Supplement", .tamil_supplement },
    .{ "Tamil", .tamil },
    .{ "Tangsa", .tangsa },
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

test "strip comment" {
    try std.testing.expectEqualSlices(u8, "0000", stripComment("0000 # comment"));
    try std.testing.expectEqualSlices(u8, "0000", stripComment("0000"));
    try std.testing.expectEqualSlices(u8, "", stripComment("# comment"));
}
