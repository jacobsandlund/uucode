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
const data = @import("../data.zig");

const UnicodeData = data.UnicodeData;
const CaseFolding = data.CaseFolding;
const DerivedCoreProperties = data.DerivedCoreProperties;
const EastAsianWidth = data.EastAsianWidth;
const GraphemeBreak = data.GraphemeBreak;
const EmojiData = data.EmojiData;

unicode_data: []UnicodeData,
case_folding: std.AutoHashMapUnmanaged(u21, CaseFolding),
derived_core_properties: std.AutoHashMapUnmanaged(u21, DerivedCoreProperties),
east_asian_width: std.AutoHashMapUnmanaged(u21, EastAsianWidth),
grapheme_break: std.AutoHashMapUnmanaged(u21, GraphemeBreak),
emoji_data: std.AutoHashMapUnmanaged(u21, EmojiData),
string_pool: std.ArrayListUnmanaged(u8),

const Ucd = @This();

pub fn init(allocator: std.mem.Allocator) !Ucd {
    const unicode_data = try allocator.alloc(UnicodeData, data.num_code_points);

    var ucd = Ucd{
        .unicode_data = unicode_data,
        .case_folding = .{},
        .derived_core_properties = .{},
        .east_asian_width = .{},
        .grapheme_break = .{},
        .emoji_data = .{},
        .string_pool = .{},
    };

    // Pre-allocate string pool capacity to prevent reallocation and pointer invalidation
    // Update this capacity if UCD files change - see bin/download-ucd.sh
    try ucd.string_pool.ensureTotalCapacityPrecise(allocator, 1152787); // Exact capacity needed

    try parseUnicodeData(allocator, ucd.unicode_data, &ucd.string_pool);
    try parseCaseFolding(allocator, &ucd.case_folding);
    try parseDerivedCoreProperties(allocator, &ucd.derived_core_properties);
    try parseEastAsianWidth(allocator, &ucd.east_asian_width);
    try parseGraphemeBreakProperty(allocator, &ucd.grapheme_break);
    try parseEmojiData(allocator, &ucd.emoji_data);

    // Assert that string pool capacity is correctly sized
    if (ucd.string_pool.items.len != ucd.string_pool.capacity) {
        std.log.info("String pool usage: {} bytes (expected: 1152787)", .{ucd.string_pool.items.len});
        @panic("String pool capacity mismatch - update capacity in init() to match actual usage");
    }

    return ucd;
}

pub fn deinit(self: *Ucd, allocator: std.mem.Allocator) void {
    allocator.free(self.unicode_data);
    self.case_folding.deinit(allocator);
    self.derived_core_properties.deinit(allocator);
    self.east_asian_width.deinit(allocator);
    self.grapheme_break.deinit(allocator);
    self.emoji_data.deinit(allocator);
    self.string_pool.deinit(allocator);
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

fn copyStringToPool(pool: *std.ArrayListUnmanaged(u8), str: []const u8) []const u8 {
    if (str.len == 0) return "";
    const start = pool.items.len;
    pool.appendSliceAssumeCapacity(str);
    return pool.items[start .. start + str.len];
}

fn parseUnicodeData(allocator: std.mem.Allocator, array: []UnicodeData, pool: *std.ArrayListUnmanaged(u8)) !void {
    const file_path = "data/ucd/UnicodeData.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 10);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var next_cp: u21 = data.min_code_point;
    const default_data = UnicodeData{
        .name = "",
        .general_category = data.GeneralCategory.Cn, // Other, not assigned
        .canonical_combining_class = 0,
        .bidi_class = data.BidiClass.L,
        .decomposition_type = "",
        .decomposition_mapping = "",
        .numeric_type = "",
        .numeric_value = "",
        .numeric_digit = "",
        .bidi_mirrored = false,
        .unicode_1_name = "",
        .iso_comment = "",
        .simple_uppercase_mapping = null,
        .simple_lowercase_mapping = null,
        .simple_titlecase_mapping = null,
    };
    var range_data: ?UnicodeData = null;

    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = parts.next() orelse continue;
        const cp = try parseCodePoint(cp_str);

        while (cp > next_cp) : (next_cp += 1) {
            // Fill any gaps or ranges
            array[next_cp - data.min_code_point] = range_data orelse default_data;
        }

        const name = parts.next() orelse "";
        const general_category_str = parts.next() orelse "";
        const canonical_combining_class = std.fmt.parseInt(u8, parts.next() orelse "0", 10) catch 0;
        const bidi_class_str = parts.next() orelse "";
        const decomposition_type = parts.next() orelse "";
        const decomposition_mapping = parts.next() orelse "";
        const numeric_type = parts.next() orelse "";
        const numeric_value = parts.next() orelse "";
        const numeric_digit = parts.next() orelse "";
        const bidi_mirrored = std.mem.eql(u8, parts.next() orelse "", "Y");
        const unicode_1_name = parts.next() orelse "";
        const iso_comment = parts.next() orelse "";
        const simple_uppercase_mapping_str = parts.next() orelse "";
        const simple_lowercase_mapping_str = parts.next() orelse "";
        const simple_titlecase_mapping_str = parts.next() orelse "";

        const general_category = std.meta.stringToEnum(data.GeneralCategory, general_category_str) orelse {
            std.log.err("Unknown general category: {s}", .{general_category_str});
            unreachable;
        };

        const bidi_class = std.meta.stringToEnum(data.BidiClass, bidi_class_str) orelse {
            std.log.err("Unknown bidi class: {s}", .{bidi_class_str});
            unreachable;
        };

        const simple_uppercase_mapping = if (simple_uppercase_mapping_str.len == 0) null else try parseCodePoint(simple_uppercase_mapping_str);
        const simple_lowercase_mapping = if (simple_lowercase_mapping_str.len == 0) null else try parseCodePoint(simple_lowercase_mapping_str);
        const simple_titlecase_mapping = if (simple_titlecase_mapping_str.len == 0) null else try parseCodePoint(simple_titlecase_mapping_str);

        const unicode_data = UnicodeData{
            .name = copyStringToPool(pool, name),
            .general_category = general_category,
            .canonical_combining_class = canonical_combining_class,
            .bidi_class = bidi_class,
            .decomposition_type = copyStringToPool(pool, decomposition_type),
            .decomposition_mapping = copyStringToPool(pool, decomposition_mapping),
            .numeric_type = copyStringToPool(pool, numeric_type),
            .numeric_value = copyStringToPool(pool, numeric_value),
            .numeric_digit = copyStringToPool(pool, numeric_digit),
            .bidi_mirrored = bidi_mirrored,
            .unicode_1_name = copyStringToPool(pool, unicode_1_name),
            .iso_comment = copyStringToPool(pool, iso_comment),
            .simple_uppercase_mapping = simple_uppercase_mapping,
            .simple_lowercase_mapping = simple_lowercase_mapping,
            .simple_titlecase_mapping = simple_titlecase_mapping,
        };

        // Handle range entries with "First>" and "Last>"
        if (std.mem.endsWith(u8, name, "First>")) {
            range_data = unicode_data;
        } else if (std.mem.endsWith(u8, name, "Last>")) {
            range_data = null;
        }

        array[cp - data.min_code_point] = unicode_data;
        next_cp = cp + 1;
    }

    // Fill any remaining gaps at the end with default values
    while (next_cp < data.code_point_range_end) : (next_cp += 1) {
        array[next_cp - data.min_code_point] = default_data;
    }
}

fn parseCaseFolding(allocator: std.mem.Allocator, map: *std.AutoHashMapUnmanaged(u21, CaseFolding)) !void {
    const file_path = "data/ucd/CaseFolding.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next() orelse continue, " \t");
        const cp = try parseCodePoint(cp_str);

        const status_str = std.mem.trim(u8, parts.next() orelse continue, " \t");
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

        const result = try map.getOrPut(allocator, cp);
        if (!result.found_existing) {
            result.value_ptr.* = CaseFolding{
                .simple = undefined,
                .full = undefined,
            };
        }

        switch (status) {
            'S', 'C' => {
                std.debug.assert(mapping_len == 1);
                result.value_ptr.simple = mapping[0];
            },
            'F' => {
                std.debug.assert(mapping_len > 1);
                for (mapping[0..mapping_len], 0..) |mapped_cp, i| {
                    result.value_ptr.full[i] = mapped_cp;
                }
            },
            'T' => {
                std.debug.assert(mapping_len == 1);
                result.value_ptr.turkish = mapping[0];
            },
            else => unreachable,
        }
    }
}

fn parseDerivedCoreProperties(allocator: std.mem.Allocator, map: *std.AutoHashMapUnmanaged(u21, DerivedCoreProperties)) !void {
    const file_path = "data/ucd/DerivedCoreProperties.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 2);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next() orelse continue, " \t");
        const property = std.mem.trim(u8, parts.next() orelse continue, " \t");

        const range = try parseCodePointRange(cp_str);

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            const result = try map.getOrPut(allocator, cp);
            if (!result.found_existing) {
                result.value_ptr.* = DerivedCoreProperties{};
            }

            if (std.mem.eql(u8, property, "Math")) {
                result.value_ptr.math = true;
            } else if (std.mem.eql(u8, property, "Alphabetic")) {
                result.value_ptr.alphabetic = true;
            } else if (std.mem.eql(u8, property, "Lowercase")) {
                result.value_ptr.lowercase = true;
            } else if (std.mem.eql(u8, property, "Uppercase")) {
                result.value_ptr.uppercase = true;
            } else if (std.mem.eql(u8, property, "Cased")) {
                result.value_ptr.cased = true;
            } else if (std.mem.eql(u8, property, "Case_Ignorable")) {
                result.value_ptr.case_ignorable = true;
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
                result.value_ptr.id_start = true;
            } else if (std.mem.eql(u8, property, "ID_Continue")) {
                result.value_ptr.id_continue = true;
            } else if (std.mem.eql(u8, property, "XID_Start")) {
                result.value_ptr.xid_start = true;
            } else if (std.mem.eql(u8, property, "XID_Continue")) {
                result.value_ptr.xid_continue = true;
            } else if (std.mem.eql(u8, property, "Default_Ignorable_Code_Point")) {
                result.value_ptr.default_ignorable_code_point = true;
            } else if (std.mem.eql(u8, property, "Grapheme_Extend")) {
                result.value_ptr.grapheme_extend = true;
            } else if (std.mem.eql(u8, property, "Grapheme_Base")) {
                result.value_ptr.grapheme_base = true;
            } else if (std.mem.eql(u8, property, "Grapheme_Link")) {
                result.value_ptr.grapheme_link = true;
            } else if (std.mem.eql(u8, property, "InCB")) {
                result.value_ptr.incb = true;
            } else {
                std.log.err("Unknown DerivedCoreProperties property: {s}", .{property});
                unreachable;
            }
        }
    }
}

fn parseEastAsianWidth(allocator: std.mem.Allocator, map: *std.AutoHashMapUnmanaged(u21, EastAsianWidth)) !void {
    const file_path = "data/ucd/extracted/DerivedEastAsianWidth.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next() orelse continue, " \t");
        const width_str = std.mem.trim(u8, parts.next() orelse continue, " \t");

        const range = try parseCodePointRange(cp_str);

        const width = if (std.mem.eql(u8, width_str, "F"))
            EastAsianWidth.fullwidth
        else if (std.mem.eql(u8, width_str, "H"))
            EastAsianWidth.halfwidth
        else if (std.mem.eql(u8, width_str, "W"))
            EastAsianWidth.wide
        else if (std.mem.eql(u8, width_str, "Na"))
            EastAsianWidth.narrow
        else if (std.mem.eql(u8, width_str, "A"))
            EastAsianWidth.ambiguous
        else if (std.mem.eql(u8, width_str, "N"))
            EastAsianWidth.neutral
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

fn parseGraphemeBreakProperty(allocator: std.mem.Allocator, map: *std.AutoHashMapUnmanaged(u21, GraphemeBreak)) !void {
    const file_path = "data/ucd/auxiliary/GraphemeBreakProperty.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next() orelse continue, " \t");
        const prop_str = std.mem.trim(u8, parts.next() orelse continue, " \t");

        const range = try parseCodePointRange(cp_str);

        const prop = if (std.mem.eql(u8, prop_str, "Prepend"))
            GraphemeBreak.prepend
        else if (std.mem.eql(u8, prop_str, "CR"))
            GraphemeBreak.cr
        else if (std.mem.eql(u8, prop_str, "LF"))
            GraphemeBreak.lf
        else if (std.mem.eql(u8, prop_str, "Control"))
            GraphemeBreak.control
        else if (std.mem.eql(u8, prop_str, "Extend"))
            GraphemeBreak.extend
        else if (std.mem.eql(u8, prop_str, "Regional_Indicator"))
            GraphemeBreak.regional_indicator
        else if (std.mem.eql(u8, prop_str, "SpacingMark"))
            GraphemeBreak.spacingmark
        else if (std.mem.eql(u8, prop_str, "L"))
            GraphemeBreak.l
        else if (std.mem.eql(u8, prop_str, "V"))
            GraphemeBreak.v
        else if (std.mem.eql(u8, prop_str, "T"))
            GraphemeBreak.t
        else if (std.mem.eql(u8, prop_str, "LV"))
            GraphemeBreak.lv
        else if (std.mem.eql(u8, prop_str, "LVT"))
            GraphemeBreak.lvt
        else if (std.mem.eql(u8, prop_str, "ZWJ"))
            GraphemeBreak.zwj
        else
            GraphemeBreak.other;

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(allocator, cp, prop);
        }
    }
}

fn parseEmojiData(allocator: std.mem.Allocator, map: *std.AutoHashMapUnmanaged(u21, EmojiData)) !void {
    const file_path = "data/ucd/emoji/emoji-data.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = std.mem.trim(u8, parts.next() orelse continue, " \t");
        const prop_str = std.mem.trim(u8, parts.next() orelse continue, " \t");

        const range = try parseCodePointRange(cp_str);

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            const result = try map.getOrPut(allocator, cp);
            if (!result.found_existing) {
                result.value_ptr.* = EmojiData{};
            }

            if (std.mem.eql(u8, prop_str, "Emoji")) {
                result.value_ptr.emoji = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Presentation")) {
                result.value_ptr.emoji_presentation = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Modifier")) {
                result.value_ptr.emoji_modifier = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Modifier_Base")) {
                result.value_ptr.emoji_modifier_base = true;
            } else if (std.mem.eql(u8, prop_str, "Emoji_Component")) {
                result.value_ptr.emoji_component = true;
            } else if (std.mem.eql(u8, prop_str, "Extended_Pictographic")) {
                result.value_ptr.extended_pictographic = true;
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

test "parse Ucd with real data" {
    const allocator = std.testing.allocator;
    var ucd = try Ucd.init(allocator);
    defer ucd.deinit(allocator);

    try std.testing.expect(ucd.unicode_data.len > 0);
    try std.testing.expect(ucd.emoji_data.count() > 0);
}
