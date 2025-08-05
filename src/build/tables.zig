const std = @import("std");
const Ucd = @import("Ucd.zig");
const types = @import("types.zig");
const config = @import("config.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

// Needs about 81 MB normally but 87 MB when `is_updating_ucd`
const buffer_size = 100_000_000;

pub fn main() !void {
    const total_start = try std.time.Instant.now();
    const table_configs: []const config.Table = if (config.is_updating_ucd) &.{config.updating_ucd_config} else &@import("build_config").tables;

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

    inline for (table_configs, 0..) |table_config, i| {
        const start = try std.time.Instant.now();

        try writeTable(
            table_config,
            arena_alloc,
            &ucd,
            writer,
        );

        std.log.debug("Arena end capacity: {d}\n", .{arena.queryCapacity()});
        _ = arena.reset(.retain_capacity);

        const end = try std.time.Instant.now();
        std.log.debug("`writeTable` for table_config {d} time: {d}ms\n", .{ i, end.since(start) / std.time.ns_per_ms });
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

pub fn writeTable(
    comptime table_config: config.Table,
    allocator: std.mem.Allocator,
    ucd: *const Ucd,
    writer: anytype,
) !void {
    const Table = types.Table(table_config);
    const Data = @typeInfo(@FieldType(Table, "data")).array.child;
    const AllData = types.AllData(table_config);

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

    var cp: u21 = 0;
    while (cp < config.code_point_range_end) : (cp += 1) {
        const unicode_data = ucd.unicode_data[cp];
        const case_folding = ucd.case_folding.get(cp);
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse types.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse types.EastAsianWidth.neutral;
        const original_grapheme_break = ucd.original_grapheme_break.get(cp) orelse types.OriginalGraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse types.EmojiData{};
        const block_value = ucd.blocks.get(cp) orelse types.Block.no_block;

        var a: AllData = undefined;

        // UnicodeData fields
        if (@hasField(AllData, "name")) {
            a.name = unicode_data.name;
        }
        if (@hasField(AllData, "general_category")) {
            a.general_category = unicode_data.general_category;
        }
        if (@hasField(AllData, "canonical_combining_class")) {
            a.canonical_combining_class = unicode_data.canonical_combining_class;
        }
        if (@hasField(AllData, "bidi_class")) {
            a.bidi_class = unicode_data.bidi_class;
        }
        if (@hasField(AllData, "decomposition_type")) {
            a.decomposition_type = unicode_data.decomposition_type;
        }
        if (@hasField(AllData, "decomposition_mapping")) {
            a.decomposition_mapping = unicode_data.decomposition_mapping;
        }
        if (@hasField(AllData, "numeric_type")) {
            a.numeric_type = unicode_data.numeric_type;
        }
        if (@hasField(AllData, "numeric_value_decimal")) {
            a.numeric_value_decimal = unicode_data.numeric_value_decimal;
        }
        if (@hasField(AllData, "numeric_value_digit")) {
            a.numeric_value_digit = unicode_data.numeric_value_digit;
        }
        if (@hasField(AllData, "numeric_value_numeric")) {
            a.numeric_value_numeric = unicode_data.numeric_value_numeric;
        }
        if (@hasField(AllData, "is_bidi_mirrored")) {
            a.is_bidi_mirrored = unicode_data.is_bidi_mirrored;
        }
        if (@hasField(AllData, "unicode_1_name")) {
            a.unicode_1_name = unicode_data.unicode_1_name;
        }
        if (@hasField(AllData, "simple_uppercase_mapping")) {
            a.simple_uppercase_mapping = unicode_data.simple_uppercase_mapping;
        }
        if (@hasField(AllData, "simple_lowercase_mapping")) {
            a.simple_lowercase_mapping = unicode_data.simple_lowercase_mapping;
        }
        if (@hasField(AllData, "simple_titlecase_mapping")) {
            a.simple_titlecase_mapping = unicode_data.simple_titlecase_mapping;
        }

        // CaseFolding fields
        if (@hasField(AllData, "case_folding_simple")) {
            if (case_folding) |cf| {
                a.case_folding_simple = cf.case_folding_simple;
            } else {
                a.case_folding_simple = .null;
            }
        }
        if (@hasField(AllData, "case_folding_turkish")) {
            if (case_folding) |cf| {
                a.case_folding_turkish = cf.case_folding_turkish;
            } else {
                a.case_folding_turkish = .null;
            }
        }
        if (@hasField(AllData, "case_folding_full")) {
            if (case_folding) |cf| {
                a.case_folding_full = cf.case_folding_full;
            } else {
                a.case_folding_full = .empty;
            }
        }

        // DerivedCoreProperties fields
        if (@hasField(AllData, "is_math")) {
            a.is_math = derived_core_properties.is_math;
        }
        if (@hasField(AllData, "is_alphabetic")) {
            a.is_alphabetic = derived_core_properties.is_alphabetic;
        }
        if (@hasField(AllData, "is_lowercase")) {
            a.is_lowercase = derived_core_properties.is_lowercase;
        }
        if (@hasField(AllData, "is_uppercase")) {
            a.is_uppercase = derived_core_properties.is_uppercase;
        }
        if (@hasField(AllData, "is_cased")) {
            a.is_cased = derived_core_properties.is_cased;
        }
        if (@hasField(AllData, "is_case_ignorable")) {
            a.is_case_ignorable = derived_core_properties.is_case_ignorable;
        }
        if (@hasField(AllData, "changes_when_lowercased")) {
            a.changes_when_lowercased = derived_core_properties.changes_when_lowercased;
        }
        if (@hasField(AllData, "changes_when_uppercased")) {
            a.changes_when_uppercased = derived_core_properties.changes_when_uppercased;
        }
        if (@hasField(AllData, "changes_when_titlecased")) {
            a.changes_when_titlecased = derived_core_properties.changes_when_titlecased;
        }
        if (@hasField(AllData, "changes_when_casefolded")) {
            a.changes_when_casefolded = derived_core_properties.changes_when_casefolded;
        }
        if (@hasField(AllData, "changes_when_casemapped")) {
            a.changes_when_casemapped = derived_core_properties.changes_when_casemapped;
        }
        if (@hasField(AllData, "is_id_start")) {
            a.is_id_start = derived_core_properties.is_id_start;
        }
        if (@hasField(AllData, "is_id_continue")) {
            a.is_id_continue = derived_core_properties.is_id_continue;
        }
        if (@hasField(AllData, "is_xid_start")) {
            a.is_xid_start = derived_core_properties.is_xid_start;
        }
        if (@hasField(AllData, "is_xid_continue")) {
            a.is_xid_continue = derived_core_properties.is_xid_continue;
        }
        if (@hasField(AllData, "is_default_ignorable_code_point")) {
            a.is_default_ignorable_code_point = derived_core_properties.is_default_ignorable_code_point;
        }
        if (@hasField(AllData, "is_grapheme_extend")) {
            a.is_grapheme_extend = derived_core_properties.is_grapheme_extend;
        }
        if (@hasField(AllData, "is_grapheme_base")) {
            a.is_grapheme_base = derived_core_properties.is_grapheme_base;
        }
        if (@hasField(AllData, "is_grapheme_link")) {
            a.is_grapheme_link = derived_core_properties.is_grapheme_link;
        }
        if (@hasField(AllData, "indic_conjunct_break")) {
            a.indic_conjunct_break = derived_core_properties.indic_conjunct_break;
        }

        // EastAsianWidth field
        if (@hasField(AllData, "east_asian_width")) {
            a.east_asian_width = east_asian_width;
        }

        // Block field
        if (@hasField(AllData, "block")) {
            a.block = block_value;
        }

        // OriginalGraphemeBreak field
        if (@hasField(AllData, "original_grapheme_break")) {
            a.original_grapheme_break = original_grapheme_break;
        }

        // EmojiData fields
        if (@hasField(AllData, "is_emoji")) {
            a.is_emoji = emoji_data.is_emoji;
        }
        if (@hasField(AllData, "has_emoji_presentation")) {
            a.has_emoji_presentation = emoji_data.has_emoji_presentation;
        }
        if (@hasField(AllData, "is_emoji_modifier")) {
            a.is_emoji_modifier = emoji_data.is_emoji_modifier;
        }
        if (@hasField(AllData, "is_emoji_modifier_base")) {
            a.is_emoji_modifier_base = emoji_data.is_emoji_modifier_base;
        }
        if (@hasField(AllData, "is_emoji_component")) {
            a.is_emoji_component = emoji_data.is_emoji_component;
        }
        if (@hasField(AllData, "is_extended_pictographic")) {
            a.is_extended_pictographic = emoji_data.is_extended_pictographic;
        }

        // GraphemeBreak field (derived)
        if (@hasField(AllData, "grapheme_break")) {
            if (emoji_data.is_emoji_modifier) {
                a.grapheme_break = .emoji_modifier;
            } else if (emoji_data.is_emoji_modifier_base) {
                a.grapheme_break = .emoji_modifier_base;
            } else if (emoji_data.is_extended_pictographic) {
                a.grapheme_break = .extended_pictographic;
            } else {
                a.grapheme_break = switch (original_grapheme_break) {
                    .other => .other,
                    .prepend => .prepend,
                    .cr => .cr,
                    .lf => .lf,
                    .control => .control,
                    .extend => .extend,
                    .regional_indicator => .regional_indicator,
                    .spacingmark => .spacingmark,
                    .l => .l,
                    .v => .v,
                    .t => .t,
                    .lv => .lv,
                    .lvt => .lvt,
                    .zwj => .zwj,
                };
            }
        }

        inline for (table_config.extensions) |extension| {
            extension.compute(cp, &a);
        }

        var d: Data = undefined;

        const data_fields = @typeInfo(Data).@"struct".fields;
        std.debug.assert(std.mem.eql(u8, data_fields[data_fields.len - 1].name, "_padding"));

        inline for (data_fields[0 .. data_fields.len - 1]) |f| {
            @field(d, f.name) = @field(a, f.name);
        }

        // TODO: support two stage (stage1 and data) tables

        const gop = try data_map.getOrPut(allocator, d);
        var data_index: u24 = undefined;
        if (gop.found_existing) {
            data_index = gop.value_ptr.*;
        } else {
            data_index = @intCast(data_array.items.len);
            gop.value_ptr.* = data_index;
            try data_array.append(allocator, d);
        }

        block[block_len] = data_index;
        block_len += 1;

        if (block_len == block_size or cp == config.code_point_range_end - 1) {
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
        \\    types.Table(.{{
        \\        .stages = .{{ .len = .{{
        \\            .stage1 = {},
        \\            .stage2 = {},
        \\            .data = {},
        \\         }}}},
        \\        .extensions = &.{{}},
        \\        .fields = &.{{
        \\
    , .{ stage1.items.len, stage2.items.len, data_array.items.len });

    const Backing = @FieldType(Table, "backing");

    inline for (table_config.fields) |f| {
        var max_offset: usize = 0;

        if (@hasField(Backing, f.name)) {
            max_offset = @field(ucd.backing, f.name).len;
        }

        if (!config.is_updating_ucd and f.max_offset != max_offset) {
            std.debug.panic("Field '{s}' configured with max_offset {d} but the actual max offset is {d}. Reconfigure with actual ({d})", .{ f.name, f.max_offset, max_offset, max_offset });
        }

        try f.runtime(.{}).write(writer);
    }

    try writer.writeAll(
        \\        },
        \\    }){
        \\        .backing = .{
        \\
    );

    inline for (@typeInfo(Backing).@"struct".fields) |field| {
        const backing = @field(ucd.backing, field.name);

        try writer.print(
            \\            .{s} = .{{
            \\                .buffer = .{{
        , .{field.name});

        for (backing.slice()) |item| {
            try writer.print("{},", .{item});
        }

        try writer.print(
            \\
            \\                }},
            \\                .len = {},
            \\            }},
            \\
        , .{backing.len});
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

    if (config.is_updating_ucd) {
        @panic("Updating Ucd -- tables not configured to actully run. flip `is_updating_ucd` to false and run again");
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
    std.testing.refAllDeclsRecursive(Ucd);
}
