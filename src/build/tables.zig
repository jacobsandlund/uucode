const std = @import("std");
const Ucd = @import("Ucd.zig");
const types = @import("types");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

// Needs about 81 MB normally but 87 MB when `updating_ucd`
const buffer_size = 100_000_000;

pub fn main() !void {
    const total_start = try std.time.Instant.now();
    const all_fields = @import("fields");

    const buffer = try std.heap.page_allocator.alloc(u8, buffer_size);
    defer std.heap.page_allocator.free(buffer);
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    const allocator = fba.allocator();

    var ucd = try Ucd.init(allocator);
    defer ucd.deinit(allocator);

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.skip(); // Skip program name

    // Get output path (only argument now)
    const output_path = args_iter.next() orelse std.debug.panic("No output file arg!", .{});

    std.log.debug("fba end_index: {d}\n", .{fba.end_index});

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    const writer = out_file.writer();

    try writer.writeAll(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const types = @import("types");
        \\
        \\
    );

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    inline for (all_fields.fields, 0..) |fields, i| {
        const start = try std.time.Instant.now();

        try writeTable(
            fields,
            i,
            arena_alloc,
            &ucd,
            writer,
        );

        std.log.debug("Arena end capacity: {d}\n", .{arena.queryCapacity()});
        _ = arena.reset(.retain_capacity);

        const end = try std.time.Instant.now();
        std.log.debug("`writeTable` for fields {d} time: {d}ms\n", .{ i, end.since(start) / std.time.ns_per_ms });
    }

    const total_end = try std.time.Instant.now();
    std.log.debug("Total time: {d}ms\n", .{total_end.since(total_start) / std.time.ns_per_ms});
}

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

pub fn writeTable(
    comptime field_names: []const []const u8,
    fields_index: usize,
    allocator: std.mem.Allocator,
    ucd: *const Ucd,
    writer: anytype,
) !void {
    const TableData = types.TableData(0, field_names, types.default_config);
    const Data = @typeInfo(@FieldType(TableData, "data")).array.child;
    const BackingArrays = @FieldType(TableData, "backing");
    const backing_fields = @typeInfo(BackingArrays).@"struct".fields;
    var backing = BackingArrays{};

    const BackingMaps = comptime blk: {
        var backing_map_fields: [backing_fields.len]std.builtin.Type.StructField = undefined;

        for (backing_fields, 0..) |field, i| {
            const BackingOffsetMap = @FieldType(Data, field.name).BackingOffsetMap;
            backing_map_fields[i] = .{
                .name = field.name,
                .type = BackingOffsetMap,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(BackingOffsetMap),
            };
        }

        break :blk @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = &backing_map_fields,
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = false,
            },
        });
    };

    const maps: BackingMaps = blk: {
        var m: BackingMaps = undefined;
        inline for (@typeInfo(BackingMaps).@"struct".fields) |field| {
            @field(m, field.name) = .empty;
        }
        break :blk m;
    };
    defer {
        inline for (@typeInfo(BackingMaps).@"struct".fields) |field| {
            @field(BackingMaps, field.name).deinit(allocator);
        }
    }

    var data_map = DataMap(Data){};
    defer data_map.deinit(allocator);
    var data_array = std.ArrayList(Data).init(allocator);
    defer data_array.deinit();

    var offsets = try std.ArrayList(u24).initCapacity(allocator, types.num_code_points);
    defer offsets.deinit();

    const build_data_start = try std.time.Instant.now();

    var cp: u21 = types.min_code_point;
    while (cp < types.code_point_range_end) : (cp += 1) {
        const unicode_data = ucd.unicode_data[cp - types.min_code_point];
        const case_folding = ucd.case_folding.get(cp);
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse types.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse types.EastAsianWidth.neutral;
        const grapheme_break = ucd.grapheme_break.get(cp) orelse types.GraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse types.EmojiData{};

        var data: Data = undefined;

        // UnicodeData fields
        if (@hasField(Data, "name")) {
            var buffer: @FieldType(unicode_data.name, "EmbeddedArrayLen") = undefined;
            data.name = try .fromSlice(
                allocator,
                &backing.name,
                &maps.name,
                unicode_data.name.toSlice(
                    ucd.backing.name,
                    &buffer,
                ),
            );
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
        if (@hasField(Data, "decomposition_mapping")) {
            var buffer: @FieldType(unicode_data.decomposition_mapping, "EmbeddedArrayLen") = undefined;
            data.decomposition_mapping = try .fromSlice(
                allocator,
                &backing.decomposition_mapping,
                &maps.decomposition_mapping,
                unicode_data.decomposition_mapping.toSlice(
                    ucd.backing.decomposition_mapping,
                    &buffer,
                ),
            );
        }
        if (@hasField(Data, "numeric_type")) {
            data.numeric_type = unicode_data.numeric_type;
        }
        if (@hasField(Data, "numeric_value_decimal")) {
            data.numeric_value_decimal = .fromOptional(unicode_data.numeric_value_decimal);
        }
        if (@hasField(Data, "numeric_value_digit")) {
            data.numeric_value_digit = .fromOptional(unicode_data.numeric_value_digit);
        }
        if (@hasField(Data, "numeric_value_numeric")) {
            var buffer: @FieldType(unicode_data.numeric_value_numeric, "EmbeddedArrayLen") = undefined;
            data.numeric_value_numeric = try .fromSlice(
                allocator,
                &backing.numeric_value_numeric,
                &maps.numeric_value_numeric,
                unicode_data.numeric_value_numeric.toSlice(
                    ucd.backing.numeric_value_numeric,
                    &buffer,
                ),
            );
        }
        if (@hasField(Data, "bidi_mirrored")) {
            data.bidi_mirrored = unicode_data.bidi_mirrored;
        }
        if (@hasField(Data, "unicode_1_name")) {
            var buffer: @FieldType(unicode_data.unicode_1_name, "EmbeddedArrayLen") = undefined;
            data.unicode_1_name = try .fromSlice(
                allocator,
                &backing.unicode_1_name,
                &maps.unicode_1_name,
                unicode_data.unicode_1_name.toSlice(
                    ucd.backing.unicode_1_name,
                    &buffer,
                ),
            );
        }
        if (@hasField(Data, "simple_uppercase_mapping")) {
            data.simple_uppercase_mapping = .fromOptional(unicode_data.simple_uppercase_mapping);
        }
        if (@hasField(Data, "simple_lowercase_mapping")) {
            data.simple_lowercase_mapping = .fromOptional(unicode_data.simple_lowercase_mapping);
        }
        if (@hasField(Data, "simple_titlecase_mapping")) {
            data.simple_titlecase_mapping = .fromOptional(unicode_data.simple_titlecase_mapping);
        }

        // CaseFolding fields
        if (@hasField(Data, "case_folding_simple")) {
            if (case_folding) |cf| {
                data.case_folding_simple = .fromOptional(cf.case_folding_simple);
            } else {
                data.case_folding_simple = .null;
            }
        }
        if (@hasField(Data, "case_folding_turkish")) {
            if (case_folding) |cf| {
                data.case_folding_turkish = .fromOptional(cf.case_folding_turkish);
            } else {
                data.case_folding_turkish = .null;
            }
        }
        if (@hasField(Data, "case_folding_full")) {
            if (case_folding) |cf| {
                var buffer: @FieldType(case_folding.case_folding_full, "EmbeddedArrayLen") = undefined;
                data.case_folding_full = try .fromSlice(
                    allocator,
                    &backing.case_folding_full,
                    &maps.case_folding_full,
                    cf.case_folding_full.toSlice(
                        ucd.backing.case_folding_full,
                        &buffer,
                    ),
                );
            } else {
                data.case_folding_full = .empty;
            }
        }

        // DerivedCoreProperties fields
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

        // EastAsianWidth field
        if (@hasField(Data, "east_asian_width")) {
            data.east_asian_width = east_asian_width;
        }

        // GraphemeBreak field
        if (@hasField(Data, "grapheme_break")) {
            data.grapheme_break = grapheme_break;
        }

        // EmojiData fields
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

    const build_data_end = try std.time.Instant.now();
    std.log.debug("Building data time: {d}ms\n", .{build_data_end.since(build_data_start) / std.time.ns_per_ms});

    const IntEquivalent = std.meta.Int(.unsigned, @bitSizeOf(Data));

    try writer.print(
        \\pub const TableData{} = types.TableData({}, &.{{
        \\
    , .{ fields_index, data_array.items.len });

    inline for (field_names) |field_name| {
        try writer.print("\"{s}\",", .{field_name});
    }
    try writer.writeAll(
        \\
        \\}, .{
        \\
    );
    inline for (@typeInfo(types.UcdConfig).@"struct".fields) |field| {
        try writer.print(
            \\    .{s} = {},
            \\
        , .{ field.name, @field(types.default_config, field.name) });
    }

    try writer.print(
        \\}});
        \\
        \\pub const data{}: TableData{} = .{{
        \\    .data = @bitCast([{}]{s}{{
        \\
    , .{ fields_index, fields_index, data_array.items.len, @typeName(IntEquivalent) });

    for (data_array.items) |item| {
        const as_int: IntEquivalent = @bitCast(item);
        try writer.print("{},", .{as_int});
    }

    try writer.writeAll(
        \\
        \\    }),
        \\    .backing = .{
        \\
    );

    inline for (backing_fields) |field| {
        try writer.print(
            \\        .{s} = .{{
            \\            .items = .{{
        , .{field.name});

        for (@field(backing, field.name).items) |item| {
            try writer.print("{},", .{item});
        }

        try writer.print(
            \\
            \\}},
            \\            .len = {},
            \\        }},
            \\
        , .{@field(backing, field.name).len});
    }

    try writer.writeAll(
        \\    },
        \\
        \\    .offsets = .{
        \\
    );

    for (offsets.items) |offset| {
        try writer.print("{},", .{offset});
    }

    try writer.writeAll(
        \\
        \\    },
        \\
        \\};
        \\
    );
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
    @import("std").testing.refAllDeclsRecursive(Ucd);
}
