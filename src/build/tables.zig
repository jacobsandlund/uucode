const std = @import("std");
const Ucd = @import("Ucd.zig");
const data = @import("../data.zig");

fn CodePointMap() type {
    return std.HashMapUnmanaged([]const u21, u24, struct {
        pub fn hash(self: @This(), s: []const u21) u64 {
            _ = self;
            return std.hash_map.hashString(std.mem.sliceAsBytes(s));
        }
        pub fn eql(self: @This(), a: []const u21, b: []const u21) bool {
            _ = self;
            return std.mem.eql(u21, a, b);
        }
    }, std.hash_map.default_max_load_percentage);
}

fn getStringOffset(
    allocator: std.mem.Allocator,
    string_map: *std.StringHashMapUnmanaged(u24),
    strings: *std.ArrayList(u8),
    str: []const u8,
) !data.OffsetLen {
    if (str.len == 0) {
        return .{ .offset = 0, .len = 0 };
    }

    if (string_map.get(str)) |offset| {
        return .{ .offset = offset, .len = @intCast(str.len) };
    }

    const offset: u24 = @intCast(strings.items.len);
    try strings.appendSlice(str);
    try string_map.put(allocator, str, offset);
    return .{ .offset = offset, .len = @intCast(str.len) };
}

fn getCodePointOffset(
    allocator: std.mem.Allocator,
    codepoint_map: *CodePointMap(),
    codepoints: *std.ArrayList(u21),
    slice: []const u21,
) !data.OffsetLen {
    if (slice.len == 0) {
        return .{ .offset = 0, .len = 0 };
    }

    if (codepoint_map.get(slice)) |offset| {
        return .{ .offset = offset, .len = @intCast(slice.len) };
    }

    const offset: u24 = @intCast(codepoints.items.len);
    try codepoints.appendSlice(slice);
    try codepoint_map.put(allocator, slice, offset);
    return .{ .offset = offset, .len = @intCast(slice.len) };
}

pub fn write(allocator: std.mem.Allocator, ucd: *const Ucd, writer: anytype) !void {
    var string_map = std.StringHashMapUnmanaged(u24){};
    defer string_map.deinit(allocator);
    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    var codepoint_map = CodePointMap(){};
    defer codepoint_map.deinit(allocator);
    var codepoints = std.ArrayList(u21).init(allocator);
    defer codepoints.deinit();

    // First pass: collect all FullData structures
    var full_data_items = try std.ArrayList(data.FullData).initCapacity(allocator, data.num_code_points);
    defer full_data_items.deinit();

    var cp: u21 = data.min_code_point;
    while (cp < data.code_point_range_end) : (cp += 1) {
        const unicode_data = ucd.unicode_data[cp - data.min_code_point];
        const case_folding = ucd.case_folding.get(cp) orelse data.CaseFolding{};
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse data.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse data.EastAsianWidth.neutral;
        const grapheme_break = ucd.grapheme_break.get(cp) orelse data.GraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse data.EmojiData{};

        const name_info = try getStringOffset(allocator, &string_map, &strings, unicode_data.name);
        const decomposition_info = try getCodePointOffset(allocator, &codepoint_map, &codepoints, unicode_data.decomposition_mapping);
        const numeric_info = try getStringOffset(allocator, &string_map, &strings, unicode_data.numeric_value_numeric);
        const unicode_1_name_info = try getStringOffset(allocator, &string_map, &strings, unicode_data.unicode_1_name);
        const iso_comment_info = try getStringOffset(allocator, &string_map, &strings, unicode_data.iso_comment);

        const full_data = data.FullData{
            // UnicodeData fields
            .name = name_info,
            .general_category = unicode_data.general_category,
            .canonical_combining_class = unicode_data.canonical_combining_class,
            .bidi_class = unicode_data.bidi_class,
            .decomposition_type = unicode_data.decomposition_type,
            .decomposition_mapping = decomposition_info,
            .numeric_type = unicode_data.numeric_type,
            .numeric_value_decimal = unicode_data.numeric_value_decimal,
            .numeric_value_digit = unicode_data.numeric_value_digit,
            .numeric_value_numeric = numeric_info,
            .bidi_mirrored = unicode_data.bidi_mirrored,
            .unicode_1_name = unicode_1_name_info,
            .iso_comment = iso_comment_info,
            .simple_uppercase_mapping = unicode_data.simple_uppercase_mapping,
            .simple_lowercase_mapping = unicode_data.simple_lowercase_mapping,
            .simple_titlecase_mapping = unicode_data.simple_titlecase_mapping,

            // CaseFolding fields
            .case_folding_simple = case_folding.simple,
            .case_folding_turkish = case_folding.turkish,
            .case_folding_full = case_folding.full,
            .case_folding_full_len = case_folding.full_len,

            // DerivedCoreProperties fields
            .math = derived_core_properties.math,
            .alphabetic = derived_core_properties.alphabetic,
            .lowercase = derived_core_properties.lowercase,
            .uppercase = derived_core_properties.uppercase,
            .cased = derived_core_properties.cased,
            .case_ignorable = derived_core_properties.case_ignorable,
            .changes_when_lowercased = derived_core_properties.changes_when_lowercased,
            .changes_when_uppercased = derived_core_properties.changes_when_uppercased,
            .changes_when_titlecased = derived_core_properties.changes_when_titlecased,
            .changes_when_casefolded = derived_core_properties.changes_when_casefolded,
            .changes_when_casemapped = derived_core_properties.changes_when_casemapped,
            .id_start = derived_core_properties.id_start,
            .id_continue = derived_core_properties.id_continue,
            .xid_start = derived_core_properties.xid_start,
            .xid_continue = derived_core_properties.xid_continue,
            .default_ignorable_code_point = derived_core_properties.default_ignorable_code_point,
            .grapheme_extend = derived_core_properties.grapheme_extend,
            .grapheme_base = derived_core_properties.grapheme_base,
            .grapheme_link = derived_core_properties.grapheme_link,
            .indic_conjunct_break = derived_core_properties.indic_conjunct_break,

            // EastAsianWidth field
            .east_asian_width = east_asian_width,

            // GraphemeBreak field
            .grapheme_break = grapheme_break,

            // EmojiData fields
            .emoji = emoji_data.emoji,
            .emoji_presentation = emoji_data.emoji_presentation,
            .emoji_modifier = emoji_data.emoji_modifier,
            .emoji_modifier_base = emoji_data.emoji_modifier_base,
            .emoji_component = emoji_data.emoji_component,
            .extended_pictographic = emoji_data.extended_pictographic,
        };

        try full_data_items.append(full_data);
    }

    // Now write the output
    try writer.print(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const data = @import("data");
        \\
        \\// TODO: Uncomment when ready for full implementation
        \\// pub const strings: [{}]u8 = .{{
        \\// 
        \\// }};
        \\// 
        \\// pub const codepoints: [{}]u21 = .{{
        \\// 
        \\// }};
        \\
        \\pub const table: [{}]u21 = .{{
        \\
    , .{ strings.items.len, codepoints.items.len, data.num_code_points });

    // Write simplified table data - just case_folding_simple for now
    for (full_data_items.items) |item| {
        try writer.print("{}, ", .{item.case_folding_simple});
    }

    try writer.writeAll(
        \\
        \\};
        \\
    );
}
