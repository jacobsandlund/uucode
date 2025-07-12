const std = @import("std");
const Ucd = @import("Ucd.zig");
const data = @import("data");

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

pub fn write(allocator: std.mem.Allocator, ucd: *const Ucd, comptime SelectedDataType: type, writer: anytype) !void {
    var string_map = std.StringHashMapUnmanaged(u24){};
    defer string_map.deinit(allocator);
    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    var codepoint_map = CodePointMap(){};
    defer codepoint_map.deinit(allocator);
    var codepoints = std.ArrayList(u21).init(allocator);
    defer codepoints.deinit();

    // Collect all SelectedData structures, only processing needed fields
    var selected_data_items = try std.ArrayList(SelectedDataType).initCapacity(allocator, data.num_code_points);
    defer selected_data_items.deinit();

    var cp: u21 = data.min_code_point;
    while (cp < data.code_point_range_end) : (cp += 1) {
        const unicode_data = ucd.unicode_data[cp - data.min_code_point];
        const case_folding = ucd.case_folding.get(cp) orelse data.CaseFolding{};
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse data.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse data.EastAsianWidth.neutral;
        const grapheme_break = ucd.grapheme_break.get(cp) orelse data.GraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse data.EmojiData{};

        var selected_data = SelectedDataType{};

        // Use comptime reflection to only process fields that exist in SelectedDataType
        const fields = std.meta.fields(SelectedDataType);
        inline for (fields) |field| {
            // Handle fields based on name. When adding new fields to SelectedData,
            // add the corresponding cases here.
            if (comptime std.mem.eql(u8, field.name, "case_folding_simple")) {
                @field(selected_data, field.name) = case_folding.simple;
            } else if (comptime std.mem.eql(u8, field.name, "case_folding_turkish")) {
                @field(selected_data, field.name) = case_folding.turkish orelse 0;
            } else if (comptime std.mem.eql(u8, field.name, "case_folding_full")) {
                @field(selected_data, field.name) = case_folding.full;
            } else if (comptime std.mem.eql(u8, field.name, "case_folding_full_len")) {
                @field(selected_data, field.name) = case_folding.full_len;
            } else if (comptime std.mem.eql(u8, field.name, "name")) {
                @field(selected_data, field.name) = try getStringOffset(allocator, &string_map, &strings, unicode_data.name);
            } else if (comptime std.mem.eql(u8, field.name, "unicode_1_name")) {
                @field(selected_data, field.name) = try getStringOffset(allocator, &string_map, &strings, unicode_data.unicode_1_name);
            } else if (comptime std.mem.eql(u8, field.name, "iso_comment")) {
                @field(selected_data, field.name) = try getStringOffset(allocator, &string_map, &strings, unicode_data.iso_comment);
            } else if (comptime std.mem.eql(u8, field.name, "numeric_value_numeric")) {
                @field(selected_data, field.name) = try getStringOffset(allocator, &string_map, &strings, unicode_data.numeric_value_numeric);
            } else if (comptime std.mem.eql(u8, field.name, "decomposition_mapping")) {
                @field(selected_data, field.name) = try getCodePointOffset(allocator, &codepoint_map, &codepoints, unicode_data.decomposition_mapping);
            } else if (comptime std.mem.eql(u8, field.name, "general_category")) {
                @field(selected_data, field.name) = unicode_data.general_category;
            } else if (comptime std.mem.eql(u8, field.name, "canonical_combining_class")) {
                @field(selected_data, field.name) = unicode_data.canonical_combining_class;
            } else if (comptime std.mem.eql(u8, field.name, "bidi_class")) {
                @field(selected_data, field.name) = unicode_data.bidi_class;
            } else if (comptime std.mem.eql(u8, field.name, "decomposition_type")) {
                @field(selected_data, field.name) = unicode_data.decomposition_type;
            } else if (comptime std.mem.eql(u8, field.name, "numeric_type")) {
                @field(selected_data, field.name) = unicode_data.numeric_type;
            } else if (comptime std.mem.eql(u8, field.name, "numeric_value_decimal")) {
                @field(selected_data, field.name) = unicode_data.numeric_value_decimal;
            } else if (comptime std.mem.eql(u8, field.name, "numeric_value_digit")) {
                @field(selected_data, field.name) = unicode_data.numeric_value_digit;
            } else if (comptime std.mem.eql(u8, field.name, "bidi_mirrored")) {
                @field(selected_data, field.name) = unicode_data.bidi_mirrored;
            } else if (comptime std.mem.eql(u8, field.name, "simple_uppercase_mapping")) {
                @field(selected_data, field.name) = unicode_data.simple_uppercase_mapping;
            } else if (comptime std.mem.eql(u8, field.name, "simple_lowercase_mapping")) {
                @field(selected_data, field.name) = unicode_data.simple_lowercase_mapping;
            } else if (comptime std.mem.eql(u8, field.name, "simple_titlecase_mapping")) {
                @field(selected_data, field.name) = unicode_data.simple_titlecase_mapping;
            } else if (comptime std.mem.eql(u8, field.name, "math")) {
                @field(selected_data, field.name) = derived_core_properties.math;
            } else if (comptime std.mem.eql(u8, field.name, "alphabetic")) {
                @field(selected_data, field.name) = derived_core_properties.alphabetic;
            } else if (comptime std.mem.eql(u8, field.name, "lowercase")) {
                @field(selected_data, field.name) = derived_core_properties.lowercase;
            } else if (comptime std.mem.eql(u8, field.name, "uppercase")) {
                @field(selected_data, field.name) = derived_core_properties.uppercase;
            } else if (comptime std.mem.eql(u8, field.name, "cased")) {
                @field(selected_data, field.name) = derived_core_properties.cased;
            } else if (comptime std.mem.eql(u8, field.name, "case_ignorable")) {
                @field(selected_data, field.name) = derived_core_properties.case_ignorable;
            } else if (comptime std.mem.eql(u8, field.name, "changes_when_lowercased")) {
                @field(selected_data, field.name) = derived_core_properties.changes_when_lowercased;
            } else if (comptime std.mem.eql(u8, field.name, "changes_when_uppercased")) {
                @field(selected_data, field.name) = derived_core_properties.changes_when_uppercased;
            } else if (comptime std.mem.eql(u8, field.name, "changes_when_titlecased")) {
                @field(selected_data, field.name) = derived_core_properties.changes_when_titlecased;
            } else if (comptime std.mem.eql(u8, field.name, "changes_when_casefolded")) {
                @field(selected_data, field.name) = derived_core_properties.changes_when_casefolded;
            } else if (comptime std.mem.eql(u8, field.name, "changes_when_casemapped")) {
                @field(selected_data, field.name) = derived_core_properties.changes_when_casemapped;
            } else if (comptime std.mem.eql(u8, field.name, "id_start")) {
                @field(selected_data, field.name) = derived_core_properties.id_start;
            } else if (comptime std.mem.eql(u8, field.name, "id_continue")) {
                @field(selected_data, field.name) = derived_core_properties.id_continue;
            } else if (comptime std.mem.eql(u8, field.name, "xid_start")) {
                @field(selected_data, field.name) = derived_core_properties.xid_start;
            } else if (comptime std.mem.eql(u8, field.name, "xid_continue")) {
                @field(selected_data, field.name) = derived_core_properties.xid_continue;
            } else if (comptime std.mem.eql(u8, field.name, "default_ignorable_code_point")) {
                @field(selected_data, field.name) = derived_core_properties.default_ignorable_code_point;
            } else if (comptime std.mem.eql(u8, field.name, "grapheme_extend")) {
                @field(selected_data, field.name) = derived_core_properties.grapheme_extend;
            } else if (comptime std.mem.eql(u8, field.name, "grapheme_base")) {
                @field(selected_data, field.name) = derived_core_properties.grapheme_base;
            } else if (comptime std.mem.eql(u8, field.name, "grapheme_link")) {
                @field(selected_data, field.name) = derived_core_properties.grapheme_link;
            } else if (comptime std.mem.eql(u8, field.name, "indic_conjunct_break")) {
                @field(selected_data, field.name) = derived_core_properties.indic_conjunct_break;
            } else if (comptime std.mem.eql(u8, field.name, "east_asian_width")) {
                @field(selected_data, field.name) = east_asian_width;
            } else if (comptime std.mem.eql(u8, field.name, "grapheme_break")) {
                @field(selected_data, field.name) = grapheme_break;
            } else if (comptime std.mem.eql(u8, field.name, "emoji")) {
                @field(selected_data, field.name) = emoji_data.emoji;
            } else if (comptime std.mem.eql(u8, field.name, "emoji_presentation")) {
                @field(selected_data, field.name) = emoji_data.emoji_presentation;
            } else if (comptime std.mem.eql(u8, field.name, "emoji_modifier")) {
                @field(selected_data, field.name) = emoji_data.emoji_modifier;
            } else if (comptime std.mem.eql(u8, field.name, "emoji_modifier_base")) {
                @field(selected_data, field.name) = emoji_data.emoji_modifier_base;
            } else if (comptime std.mem.eql(u8, field.name, "emoji_component")) {
                @field(selected_data, field.name) = emoji_data.emoji_component;
            } else if (comptime std.mem.eql(u8, field.name, "extended_pictographic")) {
                @field(selected_data, field.name) = emoji_data.extended_pictographic;
            } else {
                @compileError("Unknown field '" ++ field.name ++ "' in SelectedData");
            }
        }

        try selected_data_items.append(selected_data);
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
    for (selected_data_items.items) |item| {
        try writer.print("{}, ", .{item.case_folding_simple});
    }

    try writer.writeAll(
        \\
        \\};
        \\
    );
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
    @import("std").testing.refAllDeclsRecursive(Ucd);
}

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    const SelectedData = @import("SelectedData");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.skip(); // Skip program name
    const output_path = args_iter.next() orelse @panic("No output file arg!");

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    const writer = out_file.writer();

    var ucd = try Ucd.init(allocator);
    defer ucd.deinit(allocator);

    try write(allocator, &ucd, SelectedData.SelectedData, writer);
}
