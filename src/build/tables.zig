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

fn SelectedDataMap(comptime SelectedData: type) type {
    return std.HashMapUnmanaged(SelectedData, u24, struct {
        pub fn hash(self: @This(), s: SelectedData) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, s);
            return hasher.final();
        }
        pub fn eql(self: @This(), a: SelectedData, b: SelectedData) bool {
            _ = self;
            return std.mem.eql(u8, std.mem.asBytes(&a), std.mem.asBytes(&b));
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

fn getSelectedDataOffset(
    comptime SelectedData: type,
    allocator: std.mem.Allocator,
    selected_data_map: *SelectedDataMap(SelectedData),
    selected_data_array: *std.ArrayList(SelectedData),
    item: SelectedData,
) !u24 {
    if (selected_data_map.get(item)) |offset| {
        return offset;
    }

    const offset: u24 = @intCast(selected_data_array.items.len);
    try selected_data_array.append(item);
    try selected_data_map.put(allocator, item, offset);
    return offset;
}

pub fn write(comptime SelectedData: type, allocator: std.mem.Allocator, ucd: *const Ucd, writer: anytype) !void {
    var string_map = std.StringHashMapUnmanaged(u24){};
    defer string_map.deinit(allocator);
    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    var codepoint_map = CodePointMap(){};
    defer codepoint_map.deinit(allocator);
    var codepoints = std.ArrayList(u21).init(allocator);
    defer codepoints.deinit();

    var selected_data_map = SelectedDataMap(SelectedData){};
    defer selected_data_map.deinit(allocator);
    var selected_data_array = std.ArrayList(SelectedData).init(allocator);
    defer selected_data_array.deinit();

    var offsets = try std.ArrayList(u24).initCapacity(allocator, data.num_code_points);
    defer offsets.deinit();

    var cp: u21 = data.min_code_point;
    while (cp < data.code_point_range_end) : (cp += 1) {
        const unicode_data = ucd.unicode_data[cp - data.min_code_point];
        const case_folding = ucd.case_folding.get(cp) orelse data.CaseFolding{};
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse data.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse data.EastAsianWidth.neutral;
        const grapheme_break = ucd.grapheme_break.get(cp) orelse data.GraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse data.EmojiData{};

        var selected_data = SelectedData{};

        if (@hasField(SelectedData, "case_folding_simple")) {
            selected_data.case_folding_simple = case_folding.simple;
        }
        if (@hasField(SelectedData, "case_folding_turkish")) {
            selected_data.case_folding_turkish = case_folding.turkish orelse 0;
        }
        if (@hasField(SelectedData, "case_folding_full")) {
            selected_data.case_folding_full = case_folding.full;
        }
        if (@hasField(SelectedData, "case_folding_full_len")) {
            selected_data.case_folding_full_len = case_folding.full_len;
        }
        if (@hasField(SelectedData, "name")) {
            selected_data.name = try getStringOffset(allocator, &string_map, &strings, unicode_data.name);
        }
        if (@hasField(SelectedData, "unicode_1_name")) {
            selected_data.unicode_1_name = try getStringOffset(allocator, &string_map, &strings, unicode_data.unicode_1_name);
        }
        if (@hasField(SelectedData, "iso_comment")) {
            selected_data.iso_comment = try getStringOffset(allocator, &string_map, &strings, unicode_data.iso_comment);
        }
        if (@hasField(SelectedData, "numeric_value_numeric")) {
            selected_data.numeric_value_numeric = try getStringOffset(allocator, &string_map, &strings, unicode_data.numeric_value_numeric);
        }
        if (@hasField(SelectedData, "decomposition_mapping")) {
            selected_data.decomposition_mapping = try getCodePointOffset(allocator, &codepoint_map, &codepoints, unicode_data.decomposition_mapping);
        }
        if (@hasField(SelectedData, "general_category")) {
            selected_data.general_category = unicode_data.general_category;
        }
        if (@hasField(SelectedData, "canonical_combining_class")) {
            selected_data.canonical_combining_class = unicode_data.canonical_combining_class;
        }
        if (@hasField(SelectedData, "bidi_class")) {
            selected_data.bidi_class = unicode_data.bidi_class;
        }
        if (@hasField(SelectedData, "decomposition_type")) {
            selected_data.decomposition_type = unicode_data.decomposition_type;
        }
        if (@hasField(SelectedData, "numeric_type")) {
            selected_data.numeric_type = unicode_data.numeric_type;
        }
        if (@hasField(SelectedData, "numeric_value_decimal")) {
            selected_data.numeric_value_decimal = unicode_data.numeric_value_decimal;
        }
        if (@hasField(SelectedData, "numeric_value_digit")) {
            selected_data.numeric_value_digit = unicode_data.numeric_value_digit;
        }
        if (@hasField(SelectedData, "bidi_mirrored")) {
            selected_data.bidi_mirrored = unicode_data.bidi_mirrored;
        }
        if (@hasField(SelectedData, "simple_uppercase_mapping")) {
            selected_data.simple_uppercase_mapping = unicode_data.simple_uppercase_mapping;
        }
        if (@hasField(SelectedData, "simple_lowercase_mapping")) {
            selected_data.simple_lowercase_mapping = unicode_data.simple_lowercase_mapping;
        }
        if (@hasField(SelectedData, "simple_titlecase_mapping")) {
            selected_data.simple_titlecase_mapping = unicode_data.simple_titlecase_mapping;
        }
        if (@hasField(SelectedData, "math")) {
            selected_data.math = derived_core_properties.math;
        }
        if (@hasField(SelectedData, "alphabetic")) {
            selected_data.alphabetic = derived_core_properties.alphabetic;
        }
        if (@hasField(SelectedData, "lowercase")) {
            selected_data.lowercase = derived_core_properties.lowercase;
        }
        if (@hasField(SelectedData, "uppercase")) {
            selected_data.uppercase = derived_core_properties.uppercase;
        }
        if (@hasField(SelectedData, "cased")) {
            selected_data.cased = derived_core_properties.cased;
        }
        if (@hasField(SelectedData, "case_ignorable")) {
            selected_data.case_ignorable = derived_core_properties.case_ignorable;
        }
        if (@hasField(SelectedData, "changes_when_lowercased")) {
            selected_data.changes_when_lowercased = derived_core_properties.changes_when_lowercased;
        }
        if (@hasField(SelectedData, "changes_when_uppercased")) {
            selected_data.changes_when_uppercased = derived_core_properties.changes_when_uppercased;
        }
        if (@hasField(SelectedData, "changes_when_titlecased")) {
            selected_data.changes_when_titlecased = derived_core_properties.changes_when_titlecased;
        }
        if (@hasField(SelectedData, "changes_when_casefolded")) {
            selected_data.changes_when_casefolded = derived_core_properties.changes_when_casefolded;
        }
        if (@hasField(SelectedData, "changes_when_casemapped")) {
            selected_data.changes_when_casemapped = derived_core_properties.changes_when_casemapped;
        }
        if (@hasField(SelectedData, "id_start")) {
            selected_data.id_start = derived_core_properties.id_start;
        }
        if (@hasField(SelectedData, "id_continue")) {
            selected_data.id_continue = derived_core_properties.id_continue;
        }
        if (@hasField(SelectedData, "xid_start")) {
            selected_data.xid_start = derived_core_properties.xid_start;
        }
        if (@hasField(SelectedData, "xid_continue")) {
            selected_data.xid_continue = derived_core_properties.xid_continue;
        }
        if (@hasField(SelectedData, "default_ignorable_code_point")) {
            selected_data.default_ignorable_code_point = derived_core_properties.default_ignorable_code_point;
        }
        if (@hasField(SelectedData, "grapheme_extend")) {
            selected_data.grapheme_extend = derived_core_properties.grapheme_extend;
        }
        if (@hasField(SelectedData, "grapheme_base")) {
            selected_data.grapheme_base = derived_core_properties.grapheme_base;
        }
        if (@hasField(SelectedData, "grapheme_link")) {
            selected_data.grapheme_link = derived_core_properties.grapheme_link;
        }
        if (@hasField(SelectedData, "indic_conjunct_break")) {
            selected_data.indic_conjunct_break = derived_core_properties.indic_conjunct_break;
        }
        if (@hasField(SelectedData, "east_asian_width")) {
            selected_data.east_asian_width = east_asian_width;
        }
        if (@hasField(SelectedData, "grapheme_break")) {
            selected_data.grapheme_break = grapheme_break;
        }
        if (@hasField(SelectedData, "emoji")) {
            selected_data.emoji = emoji_data.emoji;
        }
        if (@hasField(SelectedData, "emoji_presentation")) {
            selected_data.emoji_presentation = emoji_data.emoji_presentation;
        }
        if (@hasField(SelectedData, "emoji_modifier")) {
            selected_data.emoji_modifier = emoji_data.emoji_modifier;
        }
        if (@hasField(SelectedData, "emoji_modifier_base")) {
            selected_data.emoji_modifier_base = emoji_data.emoji_modifier_base;
        }
        if (@hasField(SelectedData, "emoji_component")) {
            selected_data.emoji_component = emoji_data.emoji_component;
        }
        if (@hasField(SelectedData, "extended_pictographic")) {
            selected_data.extended_pictographic = emoji_data.extended_pictographic;
        }

        const offset = try getSelectedDataOffset(SelectedData, allocator, &selected_data_map, &selected_data_array, selected_data);
        try offsets.append(offset);
    }

    // Now write the output
    try writer.print(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const std = @import("std");
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
        \\const SelectedData = 
    , .{ strings.items.len, codepoints.items.len });

    // Generate the SelectedData type based on the fields
    const fields_info = @typeInfo(SelectedData);
    try writer.print("packed struct {{\n", .{});
    inline for (fields_info.@"struct".fields) |field| {
        try writer.print("    {s}: {s},\n", .{ field.name, @typeName(field.type) });
    }
    try writer.print("}};\n\n", .{});

    try writer.print("pub const selected_data: [{}]SelectedData = .{{\n", .{selected_data_array.items.len});

    // Write the deduplicated SelectedData array
    for (selected_data_array.items) |item| {
        // Since SelectedData is a packed struct with the field order we know,
        // we can safely write it as a struct literal
        try writer.print("    SelectedData{{ .case_folding_simple = {} }}, \n", .{item.case_folding_simple});
    }

    try writer.print(
        \\}};
        \\
        \\pub const table: [{}]u24 = .{{
        \\
    , .{data.num_code_points});

    // Write offset table
    for (offsets.items) |offset| {
        try writer.print("{}, ", .{offset});
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
    const fields = @import("fields");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.skip(); // Skip program name

    // Get output path (only argument now)
    const output_path = args_iter.next() orelse @panic("No output file arg!");

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    const writer = out_file.writer();

    var ucd = try Ucd.init(allocator);
    defer ucd.deinit(allocator);

    const SelectedData = data.SelectedData(&fields.fields);
    try write(SelectedData, allocator, &ucd, writer);
}
