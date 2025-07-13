const std = @import("std");
const Ucd = @import("Ucd.zig");
const types = @import("types");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    const all_fields = @import("fields");

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

    var string_map = std.StringHashMapUnmanaged(u24){};
    defer string_map.deinit(allocator);
    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    var codepoint_map = CodePointMap{};
    defer codepoint_map.deinit(allocator);
    var codepoints = std.ArrayList(u21).init(allocator);
    defer codepoints.deinit();

    try writer.writeAll(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const types = @import("types");
        \\
        \\
    );

    inline for (all_fields.fields, 0..) |fields, i| {
        try writeData(
            fields,
            i,
            allocator,
            &ucd,
            &string_map,
            &strings,
            &codepoint_map,
            &codepoints,
            writer,
        );
    }

    if (strings.items.len > 0) {
        try writer.print(
            \\
            \\pub const strings: [{}]u8 = "{s}";
            \\
        , .{ strings.items.len, strings.items });
    }

    if (codepoints.items.len > 0) {
        try writer.print(
            \\pub const codepoints: [{}]u21 = .{{
            \\
        , .{codepoints.items.len});

        for (codepoints.items) |item| {
            try writer.print("0x{x}", .{item});
        }

        try writer.writeAll(
            \\}};
            \\
        );
    }
}

const CodePointMap: type = std.HashMapUnmanaged([]const u21, u24, struct {
    pub fn hash(self: @This(), s: []const u21) u64 {
        _ = self;
        return std.hash_map.hashString(std.mem.sliceAsBytes(s));
    }
    pub fn eql(self: @This(), a: []const u21, b: []const u21) bool {
        _ = self;
        return std.mem.eql(u21, a, b);
    }
}, std.hash_map.default_max_load_percentage);

fn DataMap(comptime Data: type) type {
    return std.HashMapUnmanaged(Data, u24, struct {
        pub fn hash(self: @This(), s: Data) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, s);
            return hasher.final();
        }
        pub fn eql(self: @This(), a: Data, b: Data) bool {
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
) !types.OffsetLen {
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
    codepoint_map: *CodePointMap,
    codepoints: *std.ArrayList(u21),
    slice: []const u21,
) !types.OffsetLen {
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

fn getDataOffset(
    comptime Data: type,
    allocator: std.mem.Allocator,
    data_map: *DataMap(Data),
    data_array: *std.ArrayList(Data),
    item: Data,
) !u24 {
    if (data_map.get(item)) |offset| {
        return offset;
    }

    const offset: u24 = @intCast(data_array.items.len);
    try data_array.append(item);
    try data_map.put(allocator, item, offset);
    return offset;
}

pub fn writeData(
    comptime fields: []const []const u8,
    fields_index: usize,
    allocator: std.mem.Allocator,
    ucd: *const Ucd,
    string_map: *std.StringHashMapUnmanaged(u24),
    strings: *std.ArrayList(u8),
    codepoint_map: *CodePointMap,
    codepoints: *std.ArrayList(u21),
    writer: anytype,
) !void {
    const Data = types.Data(fields);

    var data_map = DataMap(Data){};
    defer data_map.deinit(allocator);
    var data_array = std.ArrayList(Data).init(allocator);
    defer data_array.deinit();

    var offsets = try std.ArrayList(u24).initCapacity(allocator, types.num_code_points);
    defer offsets.deinit();

    var cp: u21 = types.min_code_point;
    while (cp < types.code_point_range_end) : (cp += 1) {
        const unicode_data = ucd.unicode_data[cp - types.min_code_point];
        const case_folding = ucd.case_folding.get(cp) orelse types.CaseFolding{};
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse types.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse types.EastAsianWidth.neutral;
        const grapheme_break = ucd.grapheme_break.get(cp) orelse types.GraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse types.EmojiData{};

        var data = Data{};

        if (@hasField(Data, "case_folding_simple")) {
            data.case_folding_simple = case_folding.simple;
        }
        if (@hasField(Data, "case_folding_turkish")) {
            data.case_folding_turkish = case_folding.turkish orelse 0;
        }
        if (@hasField(Data, "case_folding_full")) {
            data.case_folding_full = case_folding.full;
        }
        if (@hasField(Data, "case_folding_full_len")) {
            data.case_folding_full_len = case_folding.full_len;
        }
        if (@hasField(Data, "name")) {
            data.name = try getStringOffset(allocator, string_map, strings, unicode_data.name);
        }
        if (@hasField(Data, "unicode_1_name")) {
            data.unicode_1_name = try getStringOffset(allocator, string_map, strings, unicode_data.unicode_1_name);
        }
        if (@hasField(Data, "iso_comment")) {
            data.iso_comment = try getStringOffset(allocator, string_map, strings, unicode_data.iso_comment);
        }
        if (@hasField(Data, "numeric_value_numeric")) {
            data.numeric_value_numeric = try getStringOffset(allocator, string_map, strings, unicode_data.numeric_value_numeric);
        }
        if (@hasField(Data, "decomposition_mapping")) {
            data.decomposition_mapping = try getCodePointOffset(allocator, codepoint_map, codepoints, unicode_data.decomposition_mapping);
        }
        if (@hasField(Data, "general_category")) {
            data.general_category = unicode_data.general_category;
        }
        if (@hasField(Data, "canonical_combining_class")) {
            data.canonical_combining_class = unicode_data.canonical_combining_class;
        }
        if (@hasField(Data, "bidi_class")) {
            data.bidi_class = unicode_data.bidi_class;
        }
        if (@hasField(Data, "decomposition_type")) {
            data.decomposition_type = unicode_data.decomposition_type;
        }
        if (@hasField(Data, "numeric_type")) {
            data.numeric_type = unicode_data.numeric_type;
        }
        if (@hasField(Data, "numeric_value_decimal")) {
            data.numeric_value_decimal = unicode_data.numeric_value_decimal;
        }
        if (@hasField(Data, "numeric_value_digit")) {
            data.numeric_value_digit = unicode_data.numeric_value_digit;
        }
        if (@hasField(Data, "bidi_mirrored")) {
            data.bidi_mirrored = unicode_data.bidi_mirrored;
        }
        if (@hasField(Data, "simple_uppercase_mapping")) {
            data.simple_uppercase_mapping = unicode_data.simple_uppercase_mapping;
        }
        if (@hasField(Data, "simple_lowercase_mapping")) {
            data.simple_lowercase_mapping = unicode_data.simple_lowercase_mapping;
        }
        if (@hasField(Data, "simple_titlecase_mapping")) {
            data.simple_titlecase_mapping = unicode_data.simple_titlecase_mapping;
        }
        if (@hasField(Data, "math")) {
            data.math = derived_core_properties.math;
        }
        if (@hasField(Data, "alphabetic")) {
            data.alphabetic = derived_core_properties.alphabetic;
        }
        if (@hasField(Data, "lowercase")) {
            data.lowercase = derived_core_properties.lowercase;
        }
        if (@hasField(Data, "uppercase")) {
            data.uppercase = derived_core_properties.uppercase;
        }
        if (@hasField(Data, "cased")) {
            data.cased = derived_core_properties.cased;
        }
        if (@hasField(Data, "case_ignorable")) {
            data.case_ignorable = derived_core_properties.case_ignorable;
        }
        if (@hasField(Data, "changes_when_lowercased")) {
            data.changes_when_lowercased = derived_core_properties.changes_when_lowercased;
        }
        if (@hasField(Data, "changes_when_uppercased")) {
            data.changes_when_uppercased = derived_core_properties.changes_when_uppercased;
        }
        if (@hasField(Data, "changes_when_titlecased")) {
            data.changes_when_titlecased = derived_core_properties.changes_when_titlecased;
        }
        if (@hasField(Data, "changes_when_casefolded")) {
            data.changes_when_casefolded = derived_core_properties.changes_when_casefolded;
        }
        if (@hasField(Data, "changes_when_casemapped")) {
            data.changes_when_casemapped = derived_core_properties.changes_when_casemapped;
        }
        if (@hasField(Data, "id_start")) {
            data.id_start = derived_core_properties.id_start;
        }
        if (@hasField(Data, "id_continue")) {
            data.id_continue = derived_core_properties.id_continue;
        }
        if (@hasField(Data, "xid_start")) {
            data.xid_start = derived_core_properties.xid_start;
        }
        if (@hasField(Data, "xid_continue")) {
            data.xid_continue = derived_core_properties.xid_continue;
        }
        if (@hasField(Data, "default_ignorable_code_point")) {
            data.default_ignorable_code_point = derived_core_properties.default_ignorable_code_point;
        }
        if (@hasField(Data, "grapheme_extend")) {
            data.grapheme_extend = derived_core_properties.grapheme_extend;
        }
        if (@hasField(Data, "grapheme_base")) {
            data.grapheme_base = derived_core_properties.grapheme_base;
        }
        if (@hasField(Data, "grapheme_link")) {
            data.grapheme_link = derived_core_properties.grapheme_link;
        }
        if (@hasField(Data, "indic_conjunct_break")) {
            data.indic_conjunct_break = derived_core_properties.indic_conjunct_break;
        }
        if (@hasField(Data, "east_asian_width")) {
            data.east_asian_width = east_asian_width;
        }
        if (@hasField(Data, "grapheme_break")) {
            data.grapheme_break = grapheme_break;
        }
        if (@hasField(Data, "emoji")) {
            data.emoji = emoji_data.emoji;
        }
        if (@hasField(Data, "emoji_presentation")) {
            data.emoji_presentation = emoji_data.emoji_presentation;
        }
        if (@hasField(Data, "emoji_modifier")) {
            data.emoji_modifier = emoji_data.emoji_modifier;
        }
        if (@hasField(Data, "emoji_modifier_base")) {
            data.emoji_modifier_base = emoji_data.emoji_modifier_base;
        }
        if (@hasField(Data, "emoji_component")) {
            data.emoji_component = emoji_data.emoji_component;
        }
        if (@hasField(Data, "extended_pictographic")) {
            data.extended_pictographic = emoji_data.extended_pictographic;
        }

        const offset = try getDataOffset(Data, allocator, &data_map, &data_array, data);
        try offsets.append(offset);
    }

    const fields_info = @typeInfo(Data);

    try writer.print(
        \\const Data{} = packed struct {{
        \\
    , .{fields_index});

    inline for (fields_info.@"struct".fields) |field| {
        try writer.print("    {s}: {s},\n", .{ field.name, @typeName(field.type) });
    }
    try writer.writeAll(
        \\};
        \\
        \\
    );

    try writer.print(
        \\pub const data{}: [{}]Data{} = .{{
        \\
    , .{ fields_index, data_array.items.len, fields_index });

    for (data_array.items) |item| {
        try writer.writeAll(".{");
        inline for (fields_info.@"struct".fields) |field| {
            try writer.print(".{s}={},", .{ field.name, @field(item, field.name) });
        }
        try writer.writeAll("},");
    }

    try writer.print(
        \\}};
        \\
        \\pub const table{}: [{}]u24 = .{{
        \\
    , .{ fields_index, types.num_code_points });

    for (offsets.items) |offset| {
        try writer.print("{},", .{offset});
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
