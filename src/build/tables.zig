const std = @import("std");
const Ucd = @import("Ucd.zig");
const types = @import("types.zig");
const configpkg = @import("config.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

// Needs about 81 MB normally but 87 MB when `updating_ucd`
const buffer_size = 100_000_000;

pub fn main() !void {
    const total_start = try std.time.Instant.now();
    const table_configs: []const types.TableConfig = if (configpkg.updating_ucd) &.{configpkg.updating_ucd_config} else &@import("table_configs").configs;

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
        \\const types = @import("types.zig");
        \\const config = @import("config.zig");
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
    return std.HashMapUnmanaged(Data, u24, struct {
        pub fn hash(self: @This(), data: Data) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(128572459);
            inline for (@typeInfo(Data).@"struct".fields) |field| {
                if (comptime hasAutoHash(field.type)) {
                    @field(data, field.name).autoHash(&hasher);
                } else {
                    std.hash.autoHash(&hasher, @field(data, field.name));
                }
            }
            return hasher.final();
        }

        pub fn eql(self: @This(), a: Data, b: Data) bool {
            _ = self;
            return a == b;
        }
    }, std.hash_map.default_max_load_percentage);
}

fn hasAutoHash(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum" => @hasDecl(T, "autoHash"),
        else => false,
    };
}

const block_size = 256;
const Block = [block_size]u24;

const BlockMap = std.HashMapUnmanaged(Block, u16, struct {
    pub fn hash(self: @This(), block: Block) u64 {
        _ = self;
        var hasher = std.hash.Wyhash.init(915296157);
        std.hash.autoHash(&hasher, block);
        return hasher.final();
    }

    pub fn eql(self: @This(), a: Block, b: Block) bool {
        _ = self;
        return std.mem.eql(u24, &a, &b);
    }
}, std.hash_map.default_max_load_percentage);

pub fn writeTableData(
    comptime config: types.TableConfig,
    allocator: std.mem.Allocator,
    ucd: *const Ucd,
    writer: anytype,
) !void {
    const TableData = types.TableData(config);
    const Data = @typeInfo(@FieldType(TableData, "data")).array.child;

    var data_map: DataMap(Data) = .empty;
    defer data_map.deinit(allocator);
    var data_array: std.ArrayListUnmanaged(Data) = .empty;
    defer data_array.deinit(allocator);
    var block_map: BlockMap = .empty;
    defer block_map.deinit(allocator);
    var stage2: std.ArrayListUnmanaged(u24) = .empty;
    defer stage2.deinit(allocator);
    var stage1: std.ArrayListUnmanaged(u16) = .empty;
    defer stage1.deinit(allocator);

    var block: Block = undefined;
    var block_len: usize = 0;

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
        data._padding = 0;

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
        if (@hasField(Data, "is_bidi_mirrored")) {
            data.is_bidi_mirrored = unicode_data.is_bidi_mirrored;
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
        if (@hasField(Data, "is_math")) {
            data.is_math = derived_core_properties.is_math;
        }
        if (@hasField(Data, "is_alphabetic")) {
            data.is_alphabetic = derived_core_properties.is_alphabetic;
        }
        if (@hasField(Data, "is_lowercase")) {
            data.is_lowercase = derived_core_properties.is_lowercase;
        }
        if (@hasField(Data, "is_uppercase")) {
            data.is_uppercase = derived_core_properties.is_uppercase;
        }
        if (@hasField(Data, "is_cased")) {
            data.is_cased = derived_core_properties.is_cased;
        }
        if (@hasField(Data, "is_case_ignorable")) {
            data.is_case_ignorable = derived_core_properties.is_case_ignorable;
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
        if (@hasField(Data, "is_id_start")) {
            data.is_id_start = derived_core_properties.is_id_start;
        }
        if (@hasField(Data, "is_id_continue")) {
            data.is_id_continue = derived_core_properties.is_id_continue;
        }
        if (@hasField(Data, "is_xid_start")) {
            data.is_xid_start = derived_core_properties.is_xid_start;
        }
        if (@hasField(Data, "is_xid_continue")) {
            data.is_xid_continue = derived_core_properties.is_xid_continue;
        }
        if (@hasField(Data, "is_default_ignorable_code_point")) {
            data.is_default_ignorable_code_point = derived_core_properties.is_default_ignorable_code_point;
        }
        if (@hasField(Data, "is_grapheme_extend")) {
            data.is_grapheme_extend = derived_core_properties.is_grapheme_extend;
        }
        if (@hasField(Data, "is_grapheme_base")) {
            data.is_grapheme_base = derived_core_properties.is_grapheme_base;
        }
        if (@hasField(Data, "is_grapheme_link")) {
            data.is_grapheme_link = derived_core_properties.is_grapheme_link;
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
        if (@hasField(Data, "is_emoji")) {
            data.is_emoji = emoji_data.is_emoji;
        }
        if (@hasField(Data, "has_emoji_presentation")) {
            data.has_emoji_presentation = emoji_data.has_emoji_presentation;
        }
        if (@hasField(Data, "is_emoji_modifier")) {
            data.is_emoji_modifier = emoji_data.is_emoji_modifier;
        }
        if (@hasField(Data, "is_emoji_modifier_base")) {
            data.is_emoji_modifier_base = emoji_data.is_emoji_modifier_base;
        }
        if (@hasField(Data, "is_emoji_component")) {
            data.is_emoji_component = emoji_data.is_emoji_component;
        }
        if (@hasField(Data, "is_extended_pictographic")) {
            data.is_extended_pictographic = emoji_data.is_extended_pictographic;
        }

        // TODO: support two stage (stage1 and data) tables

        const gop = try data_map.getOrPut(allocator, data);
        var data_index: u24 = undefined;
        if (gop.found_existing) {
            data_index = gop.value_ptr.*;
        } else {
            data_index = @intCast(data_array.items.len);
            gop.value_ptr.* = data_index;
            try data_array.append(allocator, data);
        }

        block[block_len] = data_index;
        block_len += 1;

        if (block_len == block_size or cp == types.code_point_range_end - 1) {
            if (block_len < block_size) @memset(block[block_len..block_size], 0);
            const gop_block = try block_map.getOrPut(allocator, block);
            var block_index: u16 = undefined;
            if (gop_block.found_existing) {
                block_index = gop_block.value_ptr.*;
            } else {
                block_index = @intCast(stage2.items.len / block_size);
                gop_block.value_ptr.* = block_index;
                try stage2.appendSlice(allocator, block[0..block_len]);
            }

            try stage1.append(allocator, block_index);
            block_len = 0;
        }
    }

    const build_data_end = try std.time.Instant.now();
    std.log.debug("Building data time: {d}ms\n", .{build_data_end.since(build_data_start) / std.time.ns_per_ms});

    try writer.print(
        \\    types.TableData(.override(&config.default, .{{
        \\        .stage1_len = {},
        \\        .stage2_len = {},
        \\        .data_len = {},
        \\        .fields = &.{{
        \\
    , .{ stage1.items.len, stage2.items.len, data_array.items.len });

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

    try writer.writeAll(
        \\
        \\    })){
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

    const IntEquivalent = std.meta.Int(.unsigned, @bitSizeOf(Data));

    try writer.print(
        \\
        \\        }},
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
        \\        .stage2 = .{
        \\
    );

    for (stage2.items) |item| {
        try writer.print("{},", .{item});
    }

    try writer.writeAll(
        \\
        \\        },
        \\        .stage1 = .{
        \\
    );

    for (stage1.items) |item| {
        try writer.print("{},", .{item});
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
