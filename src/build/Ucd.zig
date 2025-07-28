//! This File is Layer 1 of the architecture (see /AGENT.md), processing
//! the Unicode Character Database (UCD) files (see https://www.unicode.org/reports/tr44/).
//!
//! The following files are processed, with general structure:
//!
//! - UnicodeData.txt
//!   - keyed by code point
//! - CaseFolding.txt
//!   - keyed by code point
//! - DerivedCoreProperties.txt
//!   - multiple non-disjoint sections
//!   - keyed by code point(s) (range)
//! - DerivedEastAsianWidth.txt
//!   - @missing ranges overlap with main section code points
//!   - keyed by code point(s) (range)
//! - GraphemeBreakProperty.txt
//!   - keyed by code point(s) (range)
//! - emoji-data.txt
//!   - multiple non-disjoint sections
//!   - keyed by code point(s) (range)

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const config = @import("config.zig");

const table_configs = &@import("build_config").tables;

const ucd_config = blk: {
    if (config.updating_ucd) {
        break :blk config.updating_ucd_config;
    }

    var combined_fields: []const []const u8 = &[_][]const u8{};
    var c: types.TableConfig = config.default;

    for (table_configs) |tc| {
        combined_fields = combined_fields ++ tc.fields;

        for (types.TableConfig.offset_len_fields) |field| {
            if (!@field(tc, field).eql(@field(config.default, field))) {
                if (for (tc.fields) |field_name| {
                    if (std.mem.eql(u8, field_name, field)) break false;
                } else true) {
                    @compileError("Field '" ++ field ++ "' is not part of the TableConfig `fields`, even though it differs from the default");
                }

                @field(c, field) = @field(tc, field);
            }
        }
    }

    c.fields = combined_fields;

    break :blk c;
};

// TODO: use
const config_fields_map = std.static_string_map.StaticStringMap(void).initComptime(ucd_config.fields);

const UnicodeData = types.UnicodeData(ucd_config);
const CaseFolding = types.CaseFolding(ucd_config);

unicode_data: []UnicodeData,
case_folding: std.AutoHashMapUnmanaged(u21, CaseFolding),
derived_core_properties: std.AutoHashMapUnmanaged(u21, types.DerivedCoreProperties),
east_asian_width: std.AutoHashMapUnmanaged(u21, types.EastAsianWidth),
grapheme_break: std.AutoHashMapUnmanaged(u21, types.GraphemeBreak),
emoji_data: std.AutoHashMapUnmanaged(u21, types.EmojiData),
backing: *BackingArrays,

const Self = @This();

const OffsetLenData = struct {
    const name = @FieldType(UnicodeData, "name");
    const decomposition_mapping = @FieldType(UnicodeData, "decomposition_mapping");
    const numeric_value_numeric = @FieldType(UnicodeData, "numeric_value_numeric");
    const unicode_1_name = @FieldType(UnicodeData, "unicode_1_name");
    const case_folding_full = @FieldType(CaseFolding, "case_folding_full");
};

const BackingArrays = struct {
    name: OffsetLenData.name.BackingArrayLen,
    decomposition_mapping: OffsetLenData.decomposition_mapping.BackingArrayLen,
    numeric_value_numeric: OffsetLenData.numeric_value_numeric.BackingArrayLen,
    unicode_1_name: OffsetLenData.unicode_1_name.BackingArrayLen,
    case_folding_full: OffsetLenData.case_folding_full.BackingArrayLen,
};

const BackingMaps = struct {
    name: OffsetLenData.name.BackingOffsetMap,
    decomposition_mapping: OffsetLenData.decomposition_mapping.BackingOffsetMap,
    numeric_value_numeric: OffsetLenData.numeric_value_numeric.BackingOffsetMap,
    unicode_1_name: OffsetLenData.unicode_1_name.BackingOffsetMap,
    case_folding_full: OffsetLenData.case_folding_full.BackingOffsetMap,
};

const BackingLenTracking = struct {
    name: OffsetLenData.name.BackingLenTracking,
    decomposition_mapping: OffsetLenData.decomposition_mapping.BackingLenTracking,
    numeric_value_numeric: OffsetLenData.numeric_value_numeric.BackingLenTracking,
    unicode_1_name: OffsetLenData.unicode_1_name.BackingLenTracking,
    case_folding_full: OffsetLenData.case_folding_full.BackingLenTracking,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    const start = try std.time.Instant.now();

    var ucd = Self{
        .unicode_data = undefined,
        .case_folding = .{},
        .derived_core_properties = .{},
        .east_asian_width = .{},
        .grapheme_break = .{},
        .emoji_data = .{},
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
        var m: BackingMaps = undefined;
        inline for (@typeInfo(BackingMaps).@"struct".fields) |field| {
            @field(m, field.name) = .empty;
        }
        break :blk m;
    };
    defer {
        inline for (@typeInfo(BackingMaps).@"struct".fields) |field| {
            @field(maps, field.name).deinit(allocator);
        }
    }

    var tracking = blk: {
        var lt: BackingLenTracking = undefined;
        inline for (@typeInfo(BackingLenTracking).@"struct".fields) |field| {
            const field_info = @typeInfo(field.type);
            @field(lt, field.name) = [_]@field(OffsetLenData, field.name).Offset{0} ** field_info.array.len;
        }

        break :blk lt;
    };

    try parseUnicodeData(allocator, &ucd, &maps, &tracking);
    try parseCaseFolding(allocator, &ucd, &maps, &tracking);
    try parseDerivedCoreProperties(allocator, &ucd.derived_core_properties);
    try parseEastAsianWidth(allocator, &ucd.east_asian_width);
    try parseGraphemeBreakProperty(allocator, &ucd.grapheme_break);
    try parseEmojiData(allocator, &ucd.emoji_data);

    if (config.updating_ucd) {
        const expected_default_config: types.TableConfig = .override(&config.default, .{
            .name = OffsetLenData.name.minBitsConfig(&ucd.backing.name, &tracking.name),
            .decomposition_mapping = OffsetLenData.decomposition_mapping.minBitsConfig(&ucd.backing.decomposition_mapping, &tracking.decomposition_mapping),
            .numeric_value_numeric = OffsetLenData.numeric_value_numeric.minBitsConfig(&ucd.backing.numeric_value_numeric, &tracking.numeric_value_numeric),
            .unicode_1_name = OffsetLenData.unicode_1_name.minBitsConfig(&ucd.backing.unicode_1_name, &tracking.unicode_1_name),
            .case_folding_full = OffsetLenData.case_folding_full.minBitsConfig(&ucd.backing.case_folding_full, &tracking.case_folding_full),
        });

        if (!expected_default_config.eql(&config.default)) {
            std.debug.panic(
                \\
                \\ Update default config in `config.zig` with the following:
                \\
                \\
                \\pub const default = types.TableConfig{{
                \\    .fields = &[_][]const u8{{}},
                \\    .stages = .auto,
                \\    .name = .{{
                \\        .max_len = {},
                \\        .max_offset = {},
                \\        .embedded_len = {},
                \\    }},
                \\    .decomposition_mapping = .{{
                \\        .max_len = {},
                \\        .max_offset = {},
                \\        .embedded_len = {},
                \\    }},
                \\    .numeric_value_numeric = .{{
                \\        .max_len = {},
                \\        .max_offset = {},
                \\        .embedded_len = {},
                \\    }},
                \\    .unicode_1_name = .{{
                \\        .max_len = {},
                \\        .max_offset = {},
                \\        .embedded_len = {},
                \\    }},
                \\    .case_folding_full = .{{
                \\        .max_len = {},
                \\        .max_offset = {},
                \\        .embedded_len = {},
                \\    }},
                \\}};
                \\
                \\
            , .{
                expected_default_config.name.max_len,
                expected_default_config.name.max_offset,
                expected_default_config.name.embedded_len,
                expected_default_config.decomposition_mapping.max_len,
                expected_default_config.decomposition_mapping.max_offset,
                expected_default_config.decomposition_mapping.embedded_len,
                expected_default_config.numeric_value_numeric.max_len,
                expected_default_config.numeric_value_numeric.max_offset,
                expected_default_config.numeric_value_numeric.embedded_len,
                expected_default_config.unicode_1_name.max_len,
                expected_default_config.unicode_1_name.max_offset,
                expected_default_config.unicode_1_name.embedded_len,
                expected_default_config.case_folding_full.max_len,
                expected_default_config.case_folding_full.max_offset,
                expected_default_config.case_folding_full.embedded_len,
            });
        }
    }

    const end = try std.time.Instant.now();
    std.log.debug("Ucd init time: {d}ms\n", .{end.since(start) / std.time.ns_per_ms});

    return ucd;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.unicode_data);
    self.case_folding.deinit(allocator);
    self.derived_core_properties.deinit(allocator);
    self.east_asian_width.deinit(allocator);
    self.grapheme_break.deinit(allocator);
    self.emoji_data.deinit(allocator);
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
    maps: *BackingMaps,
    tracking: *BackingLenTracking,
) !void {
    const file_path = "ucd/UnicodeData.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 10);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var next_cp: u21 = 0x0000;
    const default_data = UnicodeData{
        .name = .empty,
        .general_category = types.GeneralCategory.Cn, // Other, not assigned
        .canonical_combining_class = 0,
        .bidi_class = types.BidiClass.L,
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
        const general_category = std.meta.stringToEnum(types.GeneralCategory, general_category_str) orelse {
            std.log.err("Unknown general category: {s}", .{general_category_str});
            unreachable;
        };

        const bidi_class = std.meta.stringToEnum(types.BidiClass, bidi_class_str) orelse {
            std.log.err("Unknown bidi class: {s}", .{bidi_class_str});
            unreachable;
        };

        const simple_uppercase_mapping = if (simple_uppercase_mapping_str.len == 0) null else try parseCodePoint(simple_uppercase_mapping_str);
        const simple_lowercase_mapping = if (simple_lowercase_mapping_str.len == 0) null else try parseCodePoint(simple_lowercase_mapping_str);
        const simple_titlecase_mapping = if (simple_titlecase_mapping_str.len == 0) null else try parseCodePoint(simple_titlecase_mapping_str);

        // Parse decomposition type and mapping from single field
        // Default: character decomposes to itself (field 5 empty)
        var decomposition_type = types.DecompositionType.default;
        var decomposition_mapping: OffsetLenData.decomposition_mapping = .empty;

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

                decomposition_mapping = try .fromSliceTracked(allocator, &ucd.backing.decomposition_mapping, &maps.decomposition_mapping, &tracking.decomposition_mapping, temp_mapping[0..mapping_len]);
            }
        }

        // Determine numeric type and parse values based on which field has a value
        var numeric_type = types.NumericType.none;
        var numeric_value_decimal: ?u4 = null;
        var numeric_value_digit: ?u4 = null;
        var numeric_value_numeric: OffsetLenData.numeric_value_numeric = .empty;

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
            numeric_value_numeric = try .fromSliceTracked(allocator, &ucd.backing.numeric_value_numeric, &maps.numeric_value_numeric, &tracking.numeric_value_numeric, numeric_numeric_str);
        }

        const unicode_data = UnicodeData{
            .name = try .fromSliceTracked(allocator, &ucd.backing.name, &maps.name, &tracking.name, name),
            .general_category = general_category,
            .canonical_combining_class = canonical_combining_class,
            .bidi_class = bidi_class,
            .decomposition_type = decomposition_type,
            .decomposition_mapping = decomposition_mapping,
            .numeric_type = numeric_type,
            .numeric_value_decimal = .fromOptional(numeric_value_decimal),
            .numeric_value_digit = .fromOptional(numeric_value_digit),
            .numeric_value_numeric = numeric_value_numeric,
            .is_bidi_mirrored = is_bidi_mirrored,
            .unicode_1_name = try .fromSliceTracked(allocator, &ucd.backing.unicode_1_name, &maps.unicode_1_name, &tracking.unicode_1_name, unicode_1_name),
            .simple_uppercase_mapping = .fromOptional(simple_uppercase_mapping),
            .simple_lowercase_mapping = .fromOptional(simple_lowercase_mapping),
            .simple_titlecase_mapping = .fromOptional(simple_titlecase_mapping),
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

fn parseCaseFolding(
    allocator: std.mem.Allocator,
    ucd: *Self,
    maps: *BackingMaps,
    tracking: *BackingLenTracking,
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
                .case_folding_simple = .null,
                .case_folding_turkish = .null,
                .case_folding_full = undefined,
            };
        }

        switch (status) {
            'S', 'C' => {
                std.debug.assert(mapping_len == 1);
                result.value_ptr.case_folding_simple = .{ .data = mapping[0] };
            },
            'F' => {
                std.debug.assert(mapping_len > 1);
                result.value_ptr.case_folding_full = try .fromSliceTracked(allocator, &ucd.backing.case_folding_full, &maps.case_folding_full, &tracking.case_folding_full, mapping[0..mapping_len]);
            },
            'T' => {
                std.debug.assert(mapping_len == 1);
                result.value_ptr.case_folding_turkish = .{ .data = mapping[0] };
            },
            else => unreachable,
        }
    }
}

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
    map: *std.AutoHashMapUnmanaged(u21, types.GraphemeBreak),
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
            types.GraphemeBreak.prepend
        else if (std.mem.eql(u8, prop_str, "CR"))
            types.GraphemeBreak.cr
        else if (std.mem.eql(u8, prop_str, "LF"))
            types.GraphemeBreak.lf
        else if (std.mem.eql(u8, prop_str, "Control"))
            types.GraphemeBreak.control
        else if (std.mem.eql(u8, prop_str, "Extend"))
            types.GraphemeBreak.extend
        else if (std.mem.eql(u8, prop_str, "Regional_Indicator"))
            types.GraphemeBreak.regional_indicator
        else if (std.mem.eql(u8, prop_str, "SpacingMark"))
            types.GraphemeBreak.spacingmark
        else if (std.mem.eql(u8, prop_str, "L"))
            types.GraphemeBreak.l
        else if (std.mem.eql(u8, prop_str, "V"))
            types.GraphemeBreak.v
        else if (std.mem.eql(u8, prop_str, "T"))
            types.GraphemeBreak.t
        else if (std.mem.eql(u8, prop_str, "LV"))
            types.GraphemeBreak.lv
        else if (std.mem.eql(u8, prop_str, "LVT"))
            types.GraphemeBreak.lvt
        else if (std.mem.eql(u8, prop_str, "ZWJ"))
            types.GraphemeBreak.zwj
        else
            types.GraphemeBreak.other;

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

test "strip comment" {
    try std.testing.expectEqualSlices(u8, "0000", stripComment("0000 # comment"));
    try std.testing.expectEqualSlices(u8, "0000", stripComment("0000"));
    try std.testing.expectEqualSlices(u8, "", stripComment("# comment"));
}
