const std = @import("std");
const Ucd = @import("Ucd.zig");
const types = @import("types");
const configpkg = @import("config");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

// Needs about 81 MB normally but 87 MB when `updating_ucd`
const buffer_size = 100_000_000;

pub fn main() !void {
    const total_start = try std.time.Instant.now();
    const table_configs: []const types.TableConfig = if (configpkg.updating_ucd) &.{configpkg.updating_ucd_config} else @import("table_configs").configs;

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
        \\pub const tables = .{
        \\
    );

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    inline for (table_configs, 0..) |config, i| {
        const start = try std.time.Instant.now();

        try writeTableData(
            config,
            arena_alloc,
            &ucd,
            writer,
        );

        std.log.debug("Arena end capacity: {d}\n", .{arena.queryCapacity()});
        _ = arena.reset(.retain_capacity);

        const end = try std.time.Instant.now();
        std.log.debug("`writeTableData` for config {d} time: {d}ms\n", .{ i, end.since(start) / std.time.ns_per_ms });
    }

    try writer.writeAll(
        \\
        \\};
        \\
    );

    const total_end = try std.time.Instant.now();
    std.log.debug("Total time: {d}ms\n", .{total_end.since(total_start) / std.time.ns_per_ms});
}

fn DataMap(comptime Data: type) type {
    return std.HashMapUnmanaged(Data, u21, struct {
        pub fn hash(self: @This(), data: Data) u64 {
            const hash_start = std.time.Instant.now() catch unreachable;
            _ = self;
            var hasher = std.hash.Wyhash.init(128572459);
            inline for (@typeInfo(Data).@"struct".fields) |field| {
                if (comptime hasAutoHash(field.type)) {
                    const fd = @field(data, field.name);
                    fd.autoHash(&hasher);
                } else {
                    std.hash.autoHash(&hasher, @field(data, field.name));
                }
            }
            const result = hasher.final();
            const hash_end = std.time.Instant.now() catch unreachable;
            hash_time += hash_end.since(hash_start);
            return result;
        }
        pub fn eql(self: @This(), a: Data, b: Data) bool {
            _ = self;
            const eql_start = std.time.Instant.now() catch unreachable;
            const result = std.mem.eql(u8, std.mem.asBytes(&a), std.mem.asBytes(&b));
            const eql_end = std.time.Instant.now() catch unreachable;
            eql_time += eql_end.since(eql_start);
            return result;
        }
    }, std.hash_map.default_max_load_percentage);
}

fn hasAutoHash(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum" => @hasDecl(T, "autoHash"),
        else => false,
    };
}

fn getDataOffset(
    comptime Data: type,
    allocator: std.mem.Allocator,
    data_map: *DataMap(Data),
    data_array: *std.ArrayListUnmanaged(Data),
    item: *const Data,
) !u21 {
    const gop = try data_map.getOrPut(allocator, item.*);
    if (gop.found_existing) {
        return gop.value_ptr.*;
    }

    const offset: u21 = @intCast(data_array.items.len);
    gop.value_ptr.* = offset;
    try data_array.append(allocator, gop.key_ptr.*);
    return offset;
}

var hash_time: u64 = 0;
var eql_time: u64 = 0;

pub fn writeTableData(
    comptime config: types.TableConfig,
    allocator: std.mem.Allocator,
    ucd: *const Ucd,
    writer: anytype,
) !void {
    const TableData = types.TableData(config);
    const Data = @typeInfo(@FieldType(TableData, "data")).array.child;

    var data_map = DataMap(Data){};
    defer data_map.deinit(allocator);
    var data_array: std.ArrayListUnmanaged(Data) = .empty;
    defer data_array.deinit(allocator);

    var offsets = try std.ArrayList(u21).initCapacity(allocator, types.num_code_points);
    defer offsets.deinit();

    const build_data_start = try std.time.Instant.now();

    var lookup_time: u64 = 0;
    var set_data_time: u64 = 0;
    var get_offset_time: u64 = 0;
    var append_offset_time: u64 = 0;

    var cp: u21 = types.min_code_point;
    while (cp < types.code_point_range_end) : (cp += 1) {
        const lookup_start = try std.time.Instant.now();

        if (cp % 0x1000 == 0) {
            std.log.debug("Building data for code point {x}: lookup: {d}, set_data: {d}, hash: {d}, eql: {d}, get_offset: {d}, append_offset: {d}", .{
                cp,
                lookup_time / std.time.ns_per_ms,
                set_data_time / std.time.ns_per_ms,
                hash_time / std.time.ns_per_ms,
                eql_time / std.time.ns_per_ms,
                get_offset_time / std.time.ns_per_ms,
                append_offset_time / std.time.ns_per_ms,
            });
        }

        const unicode_data = ucd.unicode_data[cp - types.min_code_point];
        const case_folding = ucd.case_folding.get(cp);
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse types.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse types.EastAsianWidth.neutral;
        const grapheme_break = ucd.grapheme_break.get(cp) orelse types.GraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse types.EmojiData{};

        const lookup_end = try std.time.Instant.now();
        lookup_time += lookup_end.since(lookup_start);

        var data: Data = undefined;

        // UnicodeData fields
        if (@hasField(Data, "name")) {
            data.name = unicode_data.name;
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
            data.decomposition_mapping = unicode_data.decomposition_mapping;
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
        if (@hasField(Data, "numeric_value_numeric")) {
            data.numeric_value_numeric = unicode_data.numeric_value_numeric;
        }
        if (@hasField(Data, "bidi_mirrored")) {
            data.bidi_mirrored = unicode_data.bidi_mirrored;
        }
        if (@hasField(Data, "unicode_1_name")) {
            data.unicode_1_name = unicode_data.unicode_1_name;
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

        // CaseFolding fields
        if (@hasField(Data, "case_folding_simple")) {
            if (case_folding) |cf| {
                data.case_folding_simple = cf.case_folding_simple;
            } else {
                data.case_folding_simple = .null;
            }
        }
        if (@hasField(Data, "case_folding_turkish")) {
            if (case_folding) |cf| {
                data.case_folding_turkish = cf.case_folding_turkish;
            } else {
                data.case_folding_turkish = .null;
            }
        }
        if (@hasField(Data, "case_folding_full")) {
            if (case_folding) |cf| {
                data.case_folding_full = cf.case_folding_full;
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

        const set_data_end = try std.time.Instant.now();
        set_data_time += set_data_end.since(lookup_end);

        const offset = try getDataOffset(Data, allocator, &data_map, &data_array, &data);
        const get_offset_end = try std.time.Instant.now();
        get_offset_time += get_offset_end.since(set_data_end);
        try offsets.append(offset);
        const append_offset_end = try std.time.Instant.now();
        append_offset_time += append_offset_end.since(get_offset_end);
    }

    const build_data_end = try std.time.Instant.now();
    std.log.debug("Building data time: {d}ms\n", .{build_data_end.since(build_data_start) / std.time.ns_per_ms});

    const IntEquivalent = std.meta.Int(.unsigned, @bitSizeOf(Data));

    if (configpkg.updating_ucd) {
        const expected_default_config: types.TableConfig = .override(&configpkg.default, .{
            .data_len = data_array.items.len,
        });

        if (!expected_default_config.eql(&configpkg.default)) {
            std.debug.panic(
                \\
                \\ Update default config in `config.zig` with the following:
                \\
                \\
                \\pub const default = TableConfig{{
                \\    .fields = &[_][]const u8{{}},
                \\    .data_len = {},
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
                expected_default_config.data_len,
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

    try writer.print(
        \\    types.TableData(.override(&types.default_config, .{{
        \\        .data_len = {},
        \\        .fields = .{{
        \\
    , .{data_array.items.len});

    inline for (config.fields) |field_name| {
        try writer.print("\"{s}\",", .{field_name});
    }
    try writer.writeAll(
        \\
        \\        },
        \\
    );
    inline for (types.TableConfig.offset_len_fields) |field| {
        if (!@field(config, field).eql(@field(configpkg.default, field))) {
            try writer.print(
                \\        .{s} = {},
                \\
            , .{ field, @field(config, field) });
        }
    }

    try writer.print(
        \\    }}){{
        \\        .data = @bitCast([{}]{s}{{
        \\
    , .{ data_array.items.len, @typeName(IntEquivalent) });

    for (data_array.items) |item| {
        const as_int: IntEquivalent = @bitCast(item);
        try writer.print("{},", .{as_int});
    }

    try writer.writeAll(
        \\
        \\        }),
        \\        .backing = .{
        \\
    );

    inline for (@typeInfo(@FieldType(TableData, "backing")).@"struct".fields) |field| {
        try writer.print(
            \\            .{s} = .{{
            \\                .items = .{{
        , .{field.name});

        for (@field(ucd.backing, field.name).items) |item| {
            try writer.print("{},", .{item});
        }

        try writer.print(
            \\
            \\                }},
            \\                .len = {},
            \\            }},
            \\
        , .{@field(ucd.backing, field.name).len});
    }

    try writer.writeAll(
        \\        },
        \\
        \\        .offsets = .{
        \\
    );

    for (offsets.items) |offset| {
        try writer.print("{},", .{offset});
    }

    try writer.writeAll(
        \\
        \\        },
        \\    },
        \\
    );
}

test {
    std.testing.refAllDeclsRecursive(@This());
    std.testing.refAllDeclsRecursive(Ucd);
}
