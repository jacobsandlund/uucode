//! This File is Layer 1 of the architecture (see /AGENT.md), processing
//! the Unicode Character Database (UCD) files (see https://www.unicode.org/reports/tr44/).
//!
//! The following UCD files are processed, with general structure:
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

pub const GeneralCategory = enum {
    Lu, // Letter, uppercase
    Ll, // Letter, lowercase
    Lt, // Letter, titlecase
    Lm, // Letter, modifier
    Lo, // Letter, other
    Mn, // Mark, nonspacing
    Mc, // Mark, spacing combining
    Me, // Mark, enclosing
    Nd, // Number, decimal digit
    Nl, // Number, letter
    No, // Number, other
    Pc, // Punctuation, connector
    Pd, // Punctuation, dash
    Ps, // Punctuation, open
    Pe, // Punctuation, close
    Pi, // Punctuation, initial quote
    Pf, // Punctuation, final quote
    Po, // Punctuation, other
    Sm, // Symbol, math
    Sc, // Symbol, currency
    Sk, // Symbol, modifier
    So, // Symbol, other
    Zs, // Separator, space
    Zl, // Separator, line
    Zp, // Separator, paragraph
    Cc, // Other, control
    Cf, // Other, format
    Cs, // Other, surrogate
    Co, // Other, private use
    Cn, // Other, not assigned
};

pub const BidiClass = enum {
    L, // Left-to-Right
    LRE, // Left-to-Right Embedding
    LRO, // Left-to-Right Override
    R, // Right-to-Left
    AL, // Right-to-Left Arabic
    RLE, // Right-to-Left Embedding
    RLO, // Right-to-Left Override
    PDF, // Pop Directional Format
    EN, // European Number
    ES, // European Number Separator
    ET, // European Number Terminator
    AN, // Arabic Number
    CS, // Common Number Separator
    NSM, // Nonspacing Mark
    BN, // Boundary Neutral
    B, // Paragraph Separator
    S, // Segment Separator
    WS, // Whitespace
    ON, // Other Neutrals
    LRI, // Left-to-Right Isolate
    RLI, // Right-to-Left Isolate
    FSI, // First Strong Isolate
    PDI, // Pop Directional Isolate
};

pub const UnicodeDataValue = struct {
    name: []const u8,
    general_category: GeneralCategory,
    canonical_combining_class: u8,
    bidi_class: BidiClass,
    decomposition_type: []const u8,
    decomposition_mapping: []const u8,
    numeric_type: []const u8,
    numeric_value: []const u8,
    numeric_digit: []const u8,
    bidi_mirrored: bool,
    unicode_1_name: []const u8,
    iso_comment: []const u8,
    simple_uppercase_mapping: ?u21,
    simple_lowercase_mapping: ?u21,
    simple_titlecase_mapping: ?u21,
};

pub const CaseFoldingValue = struct {
    status: u8,
    mapping: [3]u21,
    mapping_len: u2,
};

pub const DerivedCorePropertiesValue = packed struct {
    math: bool = false,
    alphabetic: bool = false,
    lowercase: bool = false,
    uppercase: bool = false,
    cased: bool = false,
    case_ignorable: bool = false,
    changes_when_lowercased: bool = false,
    changes_when_uppercased: bool = false,
    changes_when_titlecased: bool = false,
    changes_when_casefolded: bool = false,
    changes_when_casemapped: bool = false,
    id_start: bool = false,
    id_continue: bool = false,
    xid_start: bool = false,
    xid_continue: bool = false,
    default_ignorable_code_point: bool = false,
    grapheme_extend: bool = false,
    grapheme_base: bool = false,
    grapheme_link: bool = false,
    incb: bool = false,
};

pub const EastAsianWidthValue = enum {
    neutral,
    fullwidth,
    halfwidth,
    wide,
    narrow,
    ambiguous,
};

pub const GraphemeBreakValue = enum {
    other,
    prepend,
    cr,
    lf,
    control,
    extend,
    regional_indicator,
    spacingmark,
    l,
    v,
    t,
    lv,
    lvt,
    zwj,
};

pub const EmojiDataValue = packed struct {
    emoji: bool = false,
    emoji_presentation: bool = false,
    emoji_modifier: bool = false,
    emoji_modifier_base: bool = false,
    emoji_component: bool = false,
    extended_pictographic: bool = false,
};

pub const ParsedUCD = struct {
    unicode_data: std.AutoHashMap(u21, UnicodeDataValue),
    case_folding: std.AutoHashMap(u21, CaseFoldingValue),
    derived_core_properties: std.AutoHashMap(u21, DerivedCorePropertiesValue),
    east_asian_width: std.AutoHashMap(u21, EastAsianWidthValue),
    grapheme_break: std.AutoHashMap(u21, GraphemeBreakValue),
    emoji_data: std.AutoHashMap(u21, EmojiDataValue),

    pub fn deinit(self: *ParsedUCD) void {
        self.unicode_data.deinit();
        self.case_folding.deinit();
        self.derived_core_properties.deinit();
        self.east_asian_width.deinit();
        self.grapheme_break.deinit();
        self.emoji_data.deinit();
    }
};

pub fn parseUCD(allocator: std.mem.Allocator) !ParsedUCD {
    var unicode_data = std.AutoHashMap(u21, UnicodeDataValue).init(allocator);
    var case_folding = std.AutoHashMap(u21, CaseFoldingValue).init(allocator);
    var derived_core_properties = std.AutoHashMap(u21, DerivedCorePropertiesValue).init(allocator);
    var east_asian_width = std.AutoHashMap(u21, EastAsianWidthValue).init(allocator);
    var grapheme_break = std.AutoHashMap(u21, GraphemeBreakValue).init(allocator);
    var emoji_data = std.AutoHashMap(u21, EmojiDataValue).init(allocator);

    try parseUnicodeData(allocator, &unicode_data);
    try parseCaseFolding(allocator, &case_folding);
    try parseDerivedCoreProperties(allocator, &derived_core_properties);
    try parseEastAsianWidth(allocator, &east_asian_width);
    try parseGraphemeBreakProperty(allocator, &grapheme_break);
    try parseEmojiData(allocator, &emoji_data);

    return ParsedUCD{
        .unicode_data = unicode_data,
        .case_folding = case_folding,
        .derived_core_properties = derived_core_properties,
        .east_asian_width = east_asian_width,
        .grapheme_break = grapheme_break,
        .emoji_data = emoji_data,
    };
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

fn parseUnicodeData(allocator: std.mem.Allocator, map: *std.AutoHashMap(u21, UnicodeDataValue)) !void {
    const file_path = "data/ucd/UnicodeData.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 10);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ';');
        const cp_str = parts.next() orelse continue;
        const cp = try parseCodePoint(cp_str);

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

        const general_category = std.meta.stringToEnum(GeneralCategory, general_category_str) orelse {
            std.log.err("Unknown general category: {s}", .{general_category_str});
            unreachable;
        };

        const bidi_class = std.meta.stringToEnum(BidiClass, bidi_class_str) orelse {
            std.log.err("Unknown bidi class: {s}", .{bidi_class_str});
            unreachable;
        };

        const simple_uppercase_mapping = if (simple_uppercase_mapping_str.len == 0) null else try parseCodePoint(simple_uppercase_mapping_str);
        const simple_lowercase_mapping = if (simple_lowercase_mapping_str.len == 0) null else try parseCodePoint(simple_lowercase_mapping_str);
        const simple_titlecase_mapping = if (simple_titlecase_mapping_str.len == 0) null else try parseCodePoint(simple_titlecase_mapping_str);

        try map.put(cp, UnicodeDataValue{
            .name = name,
            .general_category = general_category,
            .canonical_combining_class = canonical_combining_class,
            .bidi_class = bidi_class,
            .decomposition_type = decomposition_type,
            .decomposition_mapping = decomposition_mapping,
            .numeric_type = numeric_type,
            .numeric_value = numeric_value,
            .numeric_digit = numeric_digit,
            .bidi_mirrored = bidi_mirrored,
            .unicode_1_name = unicode_1_name,
            .iso_comment = iso_comment,
            .simple_uppercase_mapping = simple_uppercase_mapping,
            .simple_lowercase_mapping = simple_lowercase_mapping,
            .simple_titlecase_mapping = simple_titlecase_mapping,
        });
    }
}

fn parseCaseFolding(allocator: std.mem.Allocator, map: *std.AutoHashMap(u21, CaseFoldingValue)) !void {
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

        try map.put(cp, CaseFoldingValue{
            .status = status,
            .mapping = mapping,
            .mapping_len = mapping_len,
        });
    }
}

fn parseDerivedCoreProperties(allocator: std.mem.Allocator, map: *std.AutoHashMap(u21, DerivedCorePropertiesValue)) !void {
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
            const result = try map.getOrPut(cp);
            if (!result.found_existing) {
                result.value_ptr.* = DerivedCorePropertiesValue{};
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

fn parseEastAsianWidth(allocator: std.mem.Allocator, map: *std.AutoHashMap(u21, EastAsianWidthValue)) !void {
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
            EastAsianWidthValue.fullwidth
        else if (std.mem.eql(u8, width_str, "H"))
            EastAsianWidthValue.halfwidth
        else if (std.mem.eql(u8, width_str, "W"))
            EastAsianWidthValue.wide
        else if (std.mem.eql(u8, width_str, "Na"))
            EastAsianWidthValue.narrow
        else if (std.mem.eql(u8, width_str, "A"))
            EastAsianWidthValue.ambiguous
        else if (std.mem.eql(u8, width_str, "N"))
            EastAsianWidthValue.neutral
        else {
            std.log.err("Unknown EastAsianWidth value: {s}", .{width_str});
            unreachable;
        };

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(cp, width);
        }
    }
}

fn parseGraphemeBreakProperty(allocator: std.mem.Allocator, map: *std.AutoHashMap(u21, GraphemeBreakValue)) !void {
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
            GraphemeBreakValue.prepend
        else if (std.mem.eql(u8, prop_str, "CR"))
            GraphemeBreakValue.cr
        else if (std.mem.eql(u8, prop_str, "LF"))
            GraphemeBreakValue.lf
        else if (std.mem.eql(u8, prop_str, "Control"))
            GraphemeBreakValue.control
        else if (std.mem.eql(u8, prop_str, "Extend"))
            GraphemeBreakValue.extend
        else if (std.mem.eql(u8, prop_str, "Regional_Indicator"))
            GraphemeBreakValue.regional_indicator
        else if (std.mem.eql(u8, prop_str, "SpacingMark"))
            GraphemeBreakValue.spacingmark
        else if (std.mem.eql(u8, prop_str, "L"))
            GraphemeBreakValue.l
        else if (std.mem.eql(u8, prop_str, "V"))
            GraphemeBreakValue.v
        else if (std.mem.eql(u8, prop_str, "T"))
            GraphemeBreakValue.t
        else if (std.mem.eql(u8, prop_str, "LV"))
            GraphemeBreakValue.lv
        else if (std.mem.eql(u8, prop_str, "LVT"))
            GraphemeBreakValue.lvt
        else if (std.mem.eql(u8, prop_str, "ZWJ"))
            GraphemeBreakValue.zwj
        else
            GraphemeBreakValue.other;

        var cp: u21 = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(cp, prop);
        }
    }
}

fn parseEmojiData(allocator: std.mem.Allocator, map: *std.AutoHashMap(u21, EmojiDataValue)) !void {
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
            const result = try map.getOrPut(cp);
            if (!result.found_existing) {
                result.value_ptr.* = EmojiDataValue{};
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

test "parseUCD with real data" {
    const allocator = std.testing.allocator;
    var parsed = try parseUCD(allocator);
    defer parsed.deinit();

    try std.testing.expect(parsed.unicode_data.count() > 0);
    try std.testing.expect(parsed.emoji_data.count() > 0);
}
