const std = @import("std");
const Ucd = @import("Ucd.zig");
const types = @import("types.zig");
const config = @import("config.zig");
const build_config = @import("build_config");

pub const std_options: std.Options = .{
    .log_level = if (@hasDecl(build_config, "log_level"))
        build_config.log_level
    else
        .info,
};

const buffer_size = 150_000_000; // Actual is ~148 MiB

pub fn main() !void {
    const total_start = try std.time.Instant.now();
    const table_configs: []const config.Table = if (config.is_updating_ucd) &.{updating_ucd} else &build_config.tables;

    const buffer_for_fba = try std.heap.page_allocator.alloc(u8, buffer_size);
    defer std.heap.page_allocator.free(buffer_for_fba);
    var fba = std.heap.FixedBufferAllocator.init(buffer_for_fba);
    const allocator = fba.allocator();

    var ucd = try Ucd.init(allocator);
    defer ucd.deinit(allocator);

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.skip(); // Skip program name

    // Get output path (only argument now)
    const output_path = args_iter.next() orelse std.debug.panic("No output file arg!", .{});

    std.log.debug("Fba end_index: {d}\n", .{fba.end_index});

    std.log.debug("Writing to file: {s}\n", .{output_path});

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    var buffer: [4096]u8 = undefined;
    var file_writer = out_file.writer(&buffer);
    var writer = &file_writer.interface;

    try writer.writeAll(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const std = @import("std");
        \\const types = @import("types.zig");
        \\const types_x = @import("types.x.zig");
        \\const config = @import("config.zig");
        \\const build_config = @import("build_config");
        \\
        \\
    );

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    comptime var resolved_tables: [table_configs.len]config.Table = undefined;
    inline for (table_configs, 0..) |table_config, i| {
        resolved_tables[i] = table_config.resolve();
    }

    inline for (resolved_tables, 0..) |resolved_table, i| {
        const start = try std.time.Instant.now();

        try writeTableData(
            resolved_table,
            i,
            arena_alloc,
            &ucd,
            writer,
        );

        std.log.debug("Arena end capacity: {d}\n", .{arena.queryCapacity()});
        _ = arena.reset(.retain_capacity);

        const end = try std.time.Instant.now();
        std.log.debug("`writeTableData` for table_config {d} time: {d}ms\n", .{ i, end.since(start) / std.time.ns_per_ms });
    }

    try writer.writeAll(
        \\
        \\pub const tables = .{
        \\
    );

    inline for (resolved_tables, 0..) |resolved_table, i| {
        try writeTable(
            resolved_table,
            i,
            arena_alloc,
            writer,
        );
    }

    try writer.writeAll(
        \\
        \\};
        \\
    );

    try writer.flush();

    const total_end = try std.time.Instant.now();
    std.log.debug("Total time: {d}ms\n", .{total_end.since(total_start) / std.time.ns_per_ms});

    if (config.is_updating_ucd) {
        @panic("Updating Ucd -- tables not configured to actully run. flip `is_updating_ucd` to false and run again");
    }
}

const updating_ucd_fields = brk: {
    const d = config.default;
    const max_cp: u21 = 0x10FFFF;

    @setEvalBranchQuota(5_000);
    var fields: [d.fields.len]config.Field = undefined;

    const var_len_or_shift_fields = [_]config.Field{
        d.field("name").override(.{
            .max_len = 200,
            .max_offset = 1_500_000,
        }),
        d.field("decomposition_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 40,
            .max_offset = 8_000,
        }),
        d.field("numeric_value_numeric").override(.{
            .max_len = 30,
            .max_offset = 800,
        }),
        d.field("unicode_1_name").override(.{
            .max_len = 120,
            .max_offset = 80_000,
        }),
        d.field("simple_uppercase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
        }),
        d.field("simple_lowercase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
        }),
        d.field("simple_titlecase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
        }),
        d.field("case_folding_simple").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
        }),
        d.field("case_folding_full").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 200,
        }),
        d.field("case_folding_turkish_only").override(.{
            .max_offset = 20,
        }),
        d.field("case_folding_common_only").override(.{
            .max_offset = 2_000,
        }),
        d.field("case_folding_simple_only").override(.{
            .max_offset = 300,
        }),
        d.field("case_folding_full_only").override(.{
            .max_len = 9,
            .max_offset = 500,
        }),
        d.field("special_lowercase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 50,
        }),
        d.field("special_titlecase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 200,
        }),
        d.field("special_uppercase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 300,
        }),
        d.field("special_casing_condition").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 50,
        }),
        d.field("lowercase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 100,
        }),
        d.field("titlecase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 200,
        }),
        d.field("uppercase_mapping").override(.{
            .shift_low = -@as(isize, max_cp),
            .shift_high = max_cp,
            .max_len = 9,
            .max_offset = 300,
        }),
    };

    for (var_len_or_shift_fields, 0..) |f, i| {
        fields[i] = f.override(.{
            .embedded_len = 0,
        });
    }

    var i = var_len_or_shift_fields.len;

    for (d.fields) |f| {
        switch (f.kind()) {
            .basic, .optional => {
                fields[i] = f;
                i += 1;
            },
            else => {},
        }
    }

    break :brk fields;
};

const updating_ucd = config.Table{
    .fields = &updating_ucd_fields,
};

fn hashData(comptime Data: type, hasher: anytype, data: Data) void {
    inline for (@typeInfo(Data).@"struct".fields) |field| {
        if (comptime @typeInfo(field.type) == .@"struct" and @hasDecl(field.type, "autoHash")) {
            @field(data, field.name).autoHash(hasher);
        } else {
            std.hash.autoHash(hasher, @field(data, field.name));
        }
    }
}

fn eqlData(comptime Data: type, a: Data, b: Data) bool {
    inline for (@typeInfo(Data).@"struct".fields) |field| {
        if (comptime @typeInfo(field.type) == .@"struct" and @hasDecl(field.type, "eql")) {
            if (!@field(a, field.name).eql(@field(b, field.name))) {
                return false;
            }
        } else {
            if (@field(a, field.name) != @field(b, field.name)) {
                return false;
            }
        }
    }
    return true;
}

fn DataMap(comptime Data: type) type {
    return std.HashMapUnmanaged(Data, u16, struct {
        pub fn hash(self: @This(), data: Data) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(128572459);
            hashData(Data, &hasher, data);
            return hasher.final();
        }

        pub fn eql(self: @This(), a: Data, b: Data) bool {
            _ = self;
            return eqlData(Data, a, b);
        }
    }, std.hash_map.default_max_load_percentage);
}

const block_size = 256;

fn Block(comptime T: type) type {
    std.debug.assert(T == u16 or @typeInfo(T) == .@"struct");
    return [block_size]T;
}

fn BlockMap(comptime B: type) type {
    const T = @typeInfo(B).array.child;
    return std.HashMapUnmanaged(B, u16, struct {
        pub fn hash(self: @This(), block: B) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(915296157);
            if (T == u16) {
                std.hash.autoHash(&hasher, block);
            } else {
                for (block) |item| {
                    hashData(T, &hasher, item);
                }
            }
            return hasher.final();
        }

        pub fn eql(self: @This(), a: B, b: B) bool {
            _ = self;
            if (T == u16) {
                return std.mem.eql(T, &a, &b);
            } else {
                for (a, b) |a_item, b_item| {
                    if (!eqlData(T, a_item, b_item)) {
                        return false;
                    }
                }

                return true;
            }
        }
    }, std.hash_map.default_max_load_percentage);
}

fn TableAllData(comptime c: config.Table) type {
    var x_fields_len: u16 = 0;
    var fields_len_bound: u16 = c.fields.len;
    for (c.extensions) |x| {
        x_fields_len += x.fields.len;
        fields_len_bound += x.fields.len;
        fields_len_bound += x.inputs.len;
    }
    var x_fields: [x_fields_len]config.Field = undefined;
    var x_i: usize = 0;

    // Union extension fields:
    for (c.extensions) |x| {
        for (x.fields) |xf| {
            for (x_fields[0..x_i]) |existing| {
                if (std.mem.eql(u8, existing.name, xf.name)) {
                    @compileError("Extension field '" ++ xf.name ++ "' already exists in table");
                }
            }

            x_fields[x_i] = xf;
            x_i += 1;
        }
    }

    var fields: [fields_len_bound]std.builtin.Type.StructField = undefined;
    var i: usize = 0;

    // Add Data fields:
    for (c.fields, 0..) |cf, c_i| {
        for (c.fields[0..c_i]) |existing| {
            if (std.mem.eql(u8, existing.name, cf.name)) {
                @compileError("Field '" ++ cf.name ++ "' already exists in table");
            }
        }

        // If a field isn't in `default` it's an extension field, which should
        // be in x_fields.
        if (!config.default.hasField(cf.name)) {
            const x_field: ?config.Field = for (x_fields) |xf| {
                if (std.mem.eql(u8, xf.name, cf.name)) break xf;
            } else null;

            if (x_field) |xf| {
                if (!xf.eql(cf)) {
                    @compileError("Table field '" ++ cf.name ++ "' does not match the field in the extension");
                }
            } else {
                @compileError("Table field '" ++ cf.name ++ "' not found in any of the table's extensions");
            }
        }

        const F = types.Field(cf, c.packing);
        fields[i] = .{
            .name = cf.name,
            .type = F,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(F),
        };
        i += 1;
    }

    // Add extension fields not part of Data:
    const data_fields = fields[0..i];
    loop_x_fields: for (x_fields[0..x_i]) |xf| {
        for (data_fields) |f| {
            if (std.mem.eql(u8, xf.name, f.name)) {
                continue :loop_x_fields;
            }
        }

        const F = types.Field(xf, .unpacked);
        fields[i] = .{
            .name = xf.name,
            .type = F,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(F),
        };
        i += 1;
    }

    // Add extension inputs:
    for (c.extensions) |x| {
        loop_inputs: for (x.inputs) |input| {
            for (fields[0..i]) |existing| {
                if (std.mem.eql(u8, existing.name, input)) {
                    continue :loop_inputs;
                }
            }

            const F = types.Field(config.default.field(input), .unpacked);
            fields[i] = .{
                .name = input,
                .type = F,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(F),
            };
            i += 1;
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = fields[0..i],
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

fn singleInit(
    comptime field: []const u8,
    data: anytype,
    tracking: anytype,
    cp: u21,
    d: anytype,
) void {
    const Field = @FieldType(@typeInfo(@TypeOf(data)).pointer.child, field);
    if (@typeInfo(Field) == .@"struct" and @hasDecl(Field, "initOptional")) {
        if (@typeInfo(@TypeOf(d)) == .optional) {
            @field(data, field) = .initOptional(
                &@field(tracking, field),
                cp,
                d,
            );
        } else {
            @field(data, field) = .init(
                &@field(tracking, field),
                cp,
                d,
            );
        }
    } else if (@typeInfo(Field) == .@"struct" and @hasDecl(Field, "optional")) {
        @field(data, field) = .init(d);
    } else {
        @field(data, field) = d;
    }
}

fn tablePrefix(
    comptime table_config: config.Table,
    table_index: usize,
    allocator: std.mem.Allocator,
) !struct { []const u8, []const u8 } {
    const prefix = if (table_config.name) |name|
        try std.fmt.allocPrint(allocator, "table_{s}", .{name})
    else
        try std.fmt.allocPrint(allocator, "table_{d}", .{table_index});

    const TypePrefix = if (table_config.name) |name|
        try std.fmt.allocPrint(allocator, "Table_{s}", .{name})
    else
        try std.fmt.allocPrint(allocator, "Table_{d}", .{table_index});

    return .{ prefix, TypePrefix };
}

pub fn writeTableData(
    comptime table_config: config.Table,
    table_index: usize,
    allocator: std.mem.Allocator,
    ucd: *const Ucd,
    writer: *std.Io.Writer,
) !void {
    const Data = types.Data(table_config);
    const AllData = TableAllData(table_config);
    const Backing = types.StructFromDecls(AllData, "MutableBackingBuffer");
    const Tracking = types.StructFromDecls(AllData, "Tracking");

    var backing = blk: {
        var b: Backing = undefined;
        inline for (@typeInfo(Backing).@"struct".fields) |field| {
            const c = table_config.field(field.name);
            const T = @typeInfo(field.type).pointer.child;
            @field(b, field.name) = try allocator.alloc(T, c.max_offset);
        }

        break :blk b;
    };
    defer {
        inline for (@typeInfo(Backing).@"struct".fields) |field| {
            allocator.free(@field(backing, field.name));
        }
    }

    var tracking = blk: {
        var t: Tracking = undefined;
        inline for (@typeInfo(Tracking).@"struct".fields) |field| {
            @field(t, field.name) = .{};
        }
        break :blk t;
    };
    defer {
        inline for (@typeInfo(Tracking).@"struct".fields) |field| {
            @field(tracking, field.name).deinit(allocator);
        }
    }

    const stages = table_config.stages;
    const num_stages: u2 = if (stages == .three) 3 else 2;

    const Stage2Elem = if (stages == .three)
        u16
    else
        Data;

    const B = Block(Stage2Elem);

    var data_map: DataMap(Data) = .empty;
    defer data_map.deinit(allocator);
    var stage3: std.ArrayListUnmanaged(Data) = .empty;
    defer stage3.deinit(allocator);
    var block_map: BlockMap(B) = .empty;
    defer block_map.deinit(allocator);
    var stage2: std.ArrayListUnmanaged(Stage2Elem) = .empty;
    defer stage2.deinit(allocator);
    var stage1: std.ArrayListUnmanaged(u16) = .empty;
    defer stage1.deinit(allocator);

    var block: B = undefined;
    var block_len: usize = 0;

    const build_data_start = try std.time.Instant.now();

    for (0..config.max_code_point + 1) |cp_usize| {
        const cp: u21 = @intCast(cp_usize);
        const unicode_data = ucd.unicode_data[cp];
        const case_folding = ucd.case_folding.get(cp);
        const special_casing = ucd.special_casing.get(cp);
        const derived_core_properties = ucd.derived_core_properties.get(cp) orelse Ucd.DerivedCoreProperties{};
        const east_asian_width = ucd.east_asian_width.get(cp) orelse types.EastAsianWidth.neutral;
        const original_grapheme_break = ucd.original_grapheme_break.get(cp) orelse types.OriginalGraphemeBreak.other;
        const emoji_data = ucd.emoji_data.get(cp) orelse Ucd.EmojiData{};
        const block_value = ucd.blocks.get(cp) orelse types.Block.no_block;

        var a: AllData = undefined;

        // UnicodeData fields
        if (@hasField(AllData, "name")) {
            a.name = try .fromSlice(
                allocator,
                backing.name,
                &tracking.name,
                unicode_data.name,
            );
        }
        if (@hasField(AllData, "general_category")) {
            a.general_category = unicode_data.general_category;
        }
        if (@hasField(AllData, "canonical_combining_class")) {
            a.canonical_combining_class = unicode_data.canonical_combining_class;
        }
        if (@hasField(AllData, "unicode_data_bidi_class")) {
            a.unicode_data_bidi_class = unicode_data.bidi_class;
        }
        if (@hasField(AllData, "decomposition_type")) {
            a.decomposition_type = unicode_data.decomposition_type;
        }
        if (@hasField(AllData, "decomposition_mapping")) {
            a.decomposition_mapping = try .fromSliceFor(
                allocator,
                backing.decomposition_mapping,
                &tracking.decomposition_mapping,
                unicode_data.decomposition_mapping,
                cp,
            );
        }
        if (@hasField(AllData, "numeric_type")) {
            a.numeric_type = unicode_data.numeric_type;
        }
        if (@hasField(AllData, "numeric_value_decimal")) {
            a.numeric_value_decimal = .init(unicode_data.numeric_value_decimal);
        }
        if (@hasField(AllData, "numeric_value_digit")) {
            a.numeric_value_digit = .init(unicode_data.numeric_value_digit);
        }
        if (@hasField(AllData, "numeric_value_numeric")) {
            a.numeric_value_numeric = try .fromSlice(
                allocator,
                backing.numeric_value_numeric,
                &tracking.numeric_value_numeric,
                unicode_data.numeric_value_numeric,
            );
        }
        if (@hasField(AllData, "is_bidi_mirrored")) {
            a.is_bidi_mirrored = unicode_data.is_bidi_mirrored;
        }
        if (@hasField(AllData, "unicode_1_name")) {
            a.unicode_1_name = try .fromSlice(
                allocator,
                backing.unicode_1_name,
                &tracking.unicode_1_name,
                unicode_data.unicode_1_name,
            );
        }
        if (@hasField(AllData, "simple_uppercase_mapping")) {
            singleInit(
                "simple_uppercase_mapping",
                &a,
                &tracking,
                cp,
                unicode_data.simple_uppercase_mapping,
            );
        }
        if (@hasField(AllData, "simple_lowercase_mapping")) {
            singleInit(
                "simple_lowercase_mapping",
                &a,
                &tracking,
                cp,
                unicode_data.simple_lowercase_mapping,
            );
        }
        if (@hasField(AllData, "simple_titlecase_mapping")) {
            singleInit(
                "simple_titlecase_mapping",
                &a,
                &tracking,
                cp,
                unicode_data.simple_titlecase_mapping,
            );
        }

        // CaseFolding fields
        if (@hasField(AllData, "case_folding_simple")) {
            if (case_folding) |cf| {
                const d =
                    cf.case_folding_simple_only orelse
                    cf.case_folding_common_only orelse

                    // This would seem not to be necessary based on the heading
                    // of CaseFolding.txt, but U+0130 has only an F and T
                    // mapping and no S. The T mapping is the same as the
                    // simple_lowercase_mapping so we use that here.
                    cf.case_folding_turkish_only orelse
                    cp;
                singleInit("case_folding_simple", &a, &tracking, cp, d);
            } else {
                singleInit("case_folding_simple", &a, &tracking, cp, cp);
            }
        }
        if (@hasField(AllData, "case_folding_full")) {
            if (case_folding) |cf| {
                if (cf.case_folding_full_only.len > 0) {
                    a.case_folding_full = try .fromSliceFor(
                        allocator,
                        backing.case_folding_full,
                        &tracking.case_folding_full,
                        cf.case_folding_full_only,
                        cp,
                    );
                } else {
                    a.case_folding_full = try .fromSliceFor(
                        allocator,
                        backing.case_folding_full,
                        &tracking.case_folding_full,
                        &.{cf.case_folding_common_only orelse cp},
                        cp,
                    );
                }
            } else {
                a.case_folding_full = try .fromSliceFor(
                    allocator,
                    backing.case_folding_full,
                    &tracking.case_folding_full,
                    &.{cp},
                    cp,
                );
            }
        }
        if (@hasField(AllData, "case_folding_turkish_only")) {
            if (case_folding) |cf| {
                if (cf.case_folding_turkish_only) |t| {
                    a.case_folding_turkish_only = try .fromSliceFor(
                        allocator,
                        backing.case_folding_turkish_only,
                        &tracking.case_folding_turkish_only,
                        &.{t},
                        cp,
                    );
                } else {
                    a.case_folding_turkish_only = .empty;
                }
            } else {
                a.case_folding_turkish_only = .empty;
            }
        }
        if (@hasField(AllData, "case_folding_common_only")) {
            if (case_folding) |cf| {
                if (cf.case_folding_common_only) |c| {
                    a.case_folding_common_only = try .fromSliceFor(
                        allocator,
                        backing.case_folding_common_only,
                        &tracking.case_folding_common_only,
                        &.{c},
                        cp,
                    );
                } else {
                    a.case_folding_common_only = .empty;
                }
            } else {
                a.case_folding_common_only = .empty;
            }
        }
        if (@hasField(AllData, "case_folding_simple_only")) {
            if (case_folding) |cf| {
                if (cf.case_folding_simple_only) |s| {
                    a.case_folding_simple_only = try .fromSliceFor(
                        allocator,
                        backing.case_folding_simple_only,
                        &tracking.case_folding_simple_only,
                        &.{s},
                        cp,
                    );
                } else {
                    a.case_folding_simple_only = .empty;
                }
            } else {
                a.case_folding_simple_only = .empty;
            }
        }
        if (@hasField(AllData, "case_folding_full_only")) {
            if (case_folding) |cf| {
                a.case_folding_full_only = try .fromSliceFor(
                    allocator,
                    backing.case_folding_full_only,
                    &tracking.case_folding_full_only,
                    cf.case_folding_full_only,
                    cp,
                );
            } else {
                a.case_folding_full_only = .empty;
            }
        }

        // SpecialCasing fields
        if (@hasField(AllData, "special_lowercase_mapping")) {
            if (special_casing) |sc| {
                a.special_lowercase_mapping = try .fromSliceFor(
                    allocator,
                    backing.special_lowercase_mapping,
                    &tracking.special_lowercase_mapping,
                    sc.special_lowercase_mapping,
                    cp,
                );
            } else {
                a.special_lowercase_mapping = .empty;
            }
        }
        if (@hasField(AllData, "special_titlecase_mapping")) {
            if (special_casing) |sc| {
                a.special_titlecase_mapping = try .fromSliceFor(
                    allocator,
                    backing.special_titlecase_mapping,
                    &tracking.special_titlecase_mapping,
                    sc.special_titlecase_mapping,
                    cp,
                );
            } else {
                a.special_titlecase_mapping = .empty;
            }
        }
        if (@hasField(AllData, "special_uppercase_mapping")) {
            if (special_casing) |sc| {
                a.special_uppercase_mapping = try .fromSliceFor(
                    allocator,
                    backing.special_uppercase_mapping,
                    &tracking.special_uppercase_mapping,
                    sc.special_uppercase_mapping,
                    cp,
                );
            } else {
                a.special_uppercase_mapping = .empty;
            }
        }
        if (@hasField(AllData, "special_casing_condition")) {
            if (special_casing) |sc| {
                a.special_casing_condition = try .fromSlice(
                    allocator,
                    backing.special_casing_condition,
                    &tracking.special_casing_condition,
                    sc.special_casing_condition,
                );
            } else {
                a.special_casing_condition = .empty;
            }
        }

        // Case mappings
        if (@hasField(AllData, "lowercase_mapping")) {
            const use_special = if (special_casing) |sc|
                sc.special_casing_condition.len == 0
            else
                false;

            if (use_special) {
                a.lowercase_mapping = try .fromSliceFor(
                    allocator,
                    backing.lowercase_mapping,
                    &tracking.lowercase_mapping,
                    special_casing.?.special_lowercase_mapping,
                    cp,
                );
            } else {
                a.lowercase_mapping = try .fromSliceFor(
                    allocator,
                    backing.lowercase_mapping,
                    &tracking.lowercase_mapping,
                    &.{unicode_data.simple_lowercase_mapping orelse cp},
                    cp,
                );
            }
        }

        if (@hasField(AllData, "titlecase_mapping")) {
            const use_special = if (special_casing) |sc|
                sc.special_casing_condition.len == 0
            else
                false;

            if (use_special) {
                a.titlecase_mapping = try .fromSliceFor(
                    allocator,
                    backing.titlecase_mapping,
                    &tracking.titlecase_mapping,
                    special_casing.?.special_titlecase_mapping,
                    cp,
                );
            } else {
                a.titlecase_mapping = try .fromSliceFor(
                    allocator,
                    backing.titlecase_mapping,
                    &tracking.titlecase_mapping,
                    &.{unicode_data.simple_titlecase_mapping orelse cp},
                    cp,
                );
            }
        }

        if (@hasField(AllData, "uppercase_mapping")) {
            const use_special = if (special_casing) |sc|
                sc.special_casing_condition.len == 0
            else
                false;

            if (use_special) {
                a.uppercase_mapping = try .fromSliceFor(
                    allocator,
                    backing.uppercase_mapping,
                    &tracking.uppercase_mapping,
                    special_casing.?.special_uppercase_mapping,
                    cp,
                );
            } else {
                a.uppercase_mapping = try .fromSliceFor(
                    allocator,
                    backing.uppercase_mapping,
                    &tracking.uppercase_mapping,
                    &.{unicode_data.simple_uppercase_mapping orelse cp},
                    cp,
                );
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
        if (@hasField(AllData, "is_emoji_presentation")) {
            a.is_emoji_presentation = emoji_data.is_emoji_presentation;
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
            if (emoji_data.is_extended_pictographic) {
                std.debug.assert(original_grapheme_break == .other);
                a.grapheme_break = .extended_pictographic;
            } else {
                switch (derived_core_properties.indic_conjunct_break) {
                    .none => {
                        a.grapheme_break = switch (original_grapheme_break) {
                            .extend => blk: {
                                if (cp == config.zero_width_non_joiner) {
                                    break :blk .zwnj;
                                } else {
                                    std.log.err(
                                        "Found an `extend` grapheme break that is Indic conjunct break `none` (and not zwnj): {x}",
                                        .{cp},
                                    );
                                    unreachable;
                                }
                            },
                            inline else => |o| comptime std.meta.stringToEnum(
                                types.GraphemeBreak,
                                @tagName(o),
                            ) orelse unreachable,
                        };
                    },
                    .extend => {
                        if (cp == config.zero_width_joiner) {
                            a.grapheme_break = .zwj;
                        } else {
                            std.debug.assert(original_grapheme_break == .extend);
                            a.grapheme_break = .indic_conjunct_break_extend;
                        }
                    },
                    .linker => {
                        std.debug.assert(original_grapheme_break == .extend);
                        a.grapheme_break = .indic_conjunct_break_linker;
                    },
                    .consonant => {
                        std.debug.assert(original_grapheme_break == .other);
                        a.grapheme_break = .indic_conjunct_break_consonant;
                    },
                }
            }
        }

        inline for (table_config.extensions) |extension| {
            extension.compute(cp, &a, &backing, &tracking);
        }

        var d: Data = undefined;

        inline for (@typeInfo(Data).@"struct".fields) |f| {
            @field(d, f.name) = @field(a, f.name);
        }

        if (stages == .three) {
            const gop = try data_map.getOrPut(allocator, d);
            var data_index: u16 = undefined;
            if (gop.found_existing) {
                data_index = gop.value_ptr.*;
            } else {
                data_index = @intCast(stage3.items.len);
                gop.value_ptr.* = data_index;
                try stage3.append(allocator, d);
            }

            block[block_len] = data_index;
            block_len += 1;
        } else {
            block[block_len] = d;
            block_len += 1;
        }

        if (block_len == block_size) {
            const gop_block = try block_map.getOrPut(allocator, block);
            var block_offset: u16 = undefined;
            if (gop_block.found_existing) {
                block_offset = gop_block.value_ptr.*;
            } else {
                block_offset = @intCast(stage2.items.len);
                gop_block.value_ptr.* = block_offset;
                try stage2.appendSlice(allocator, &block);
            }

            try stage1.append(allocator, block_offset);
            block_len = 0;
        }
    }

    std.debug.assert(block_len == 0);

    const build_data_end = try std.time.Instant.now();
    std.log.debug("Building data time: {d}ms\n", .{build_data_end.since(build_data_start) / std.time.ns_per_ms});

    const prefix, const TypePrefix = try tablePrefix(table_config, table_index, allocator);

    try writer.print(
        \\const {s}_config = config.Table{{
        \\
    , .{prefix});

    try writer.writeAll("    .packing = ");
    try table_config.packing.write(writer);

    try writer.writeAll(
        \\,
        \\    .fields = &.{
        \\
    );

    var all_fields_okay = true;

    inline for (table_config.fields) |f| {
        const r = f.runtime();

        if (@hasField(Tracking, f.name)) {
            const t = @field(tracking, f.name);
            if (config.is_updating_ucd) {
                const min_config = t.minBitsConfig(r);
                if (!config.default.field(f.name).runtime().eql(min_config)) {
                    var buffer: [4096]u8 = undefined;
                    var stderr_writer = &std.fs.File.stderr().writer(&buffer);
                    var w = &stderr_writer.interface;
                    try w.writeAll(
                        \\
                        \\Update default config in `config.zig` with the correct field config:
                        \\
                    );
                    try min_config.write(w);
                    try w.flush();
                }
            } else {
                if (!r.compareActual(t.actualConfig(r))) {
                    all_fields_okay = false;
                }
            }
        }

        try r.write(writer);
    }

    if (!all_fields_okay) {
        @panic("Table config doesn't match actual. See above for details");
    }

    try writer.print(
        \\    }},
        \\}};
        \\
        \\const {s}_Data = types.Data({s}_config);
        \\const {s}_Backing = types.Backing({s}_Data);
        \\
    ,
        .{ TypePrefix, prefix, TypePrefix, TypePrefix },
    );

    inline for (@typeInfo(Backing).@"struct".fields) |field| {
        if (!@hasField(Data, field.name)) continue;

        const T = @typeInfo(field.type).pointer.child;

        try writer.print("const {s}_backing_{s}: []const {s} = ", .{
            prefix,
            field.name,
            @typeName(T),
        });

        const b = @field(backing, field.name);
        const t = @field(tracking, field.name);

        if (T == u8) {
            try writer.print("\"{s}\";\n", .{b[0..t.max_offset]});
        } else {
            try writer.writeAll("&.{");

            for (b[0..t.max_offset]) |item| {
                try writer.print("{},", .{item});
            }

            try writer.writeAll(
                \\};
                \\
            );
        }
    }

    try writer.print(
        \\
        \\const {s}_backing = {s}_Backing{{
        \\
    ,
        .{ prefix, TypePrefix },
    );

    inline for (@typeInfo(Backing).@"struct".fields) |field| {
        if (!@hasField(Data, field.name)) continue;

        try writer.print(
            \\    .{s} = {s}_backing_{s},
            \\
        , .{
            field.name,
            prefix,
            field.name,
        });
    }

    try writer.print(
        \\}};
        \\
        \\const {s}_stage1: [{d}]u16 align(std.atomic.cache_line) = .{{
        \\
    ,
        .{ prefix, stage1.items.len },
    );

    for (stage1.items) |item| {
        try writer.print("{},", .{item});
    }

    if (stages == .three) {
        try writer.print(
            \\
            \\}};
            \\
            \\const {s}_stage2: [{d}]u16 align(std.atomic.cache_line) = .{{
            \\
        ,
            .{ prefix, stage2.items.len },
        );

        for (stage2.items) |item| {
            try writer.print("{},", .{item});
        }
    }

    const data_items = if (stages == .three) stage3.items else stage2.items;

    try writer.writeAll(
        \\
        \\};
        \\
        \\
    );

    try writer.print(
        "const {s}_stage{d}: [{d}]{s}_Data align(@max(std.atomic.cache_line, @alignOf({s}_Data))) = ",
        .{ prefix, num_stages, data_items.len, TypePrefix, TypePrefix },
    );

    try types.writeDataItems(Data, writer, data_items);

    try writer.writeAll(
        \\
        \\
    );
}

fn writeTable(
    comptime table_config: config.Table,
    table_index: usize,
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
) !void {
    if (table_config.name) |name| {
        try writer.print("    .{s} = ", .{name});
    } else {
        try writer.print("    .@\"{d}\" = ", .{table_index});
    }

    const prefix, const TypePrefix = try tablePrefix(table_config, table_index, allocator);
    const num_stages: u2 = if (table_config.stages == .three) 3 else 2;

    try writer.print(
        \\types.Table{d}({s}_Data, {s}_Backing){{
        \\        .stage1 = &{s}_stage1,
        \\        .stage2 = &{s}_stage2,
        \\
    , .{
        num_stages,
        TypePrefix,
        TypePrefix,
        prefix,
        prefix,
    });

    if (table_config.stages == .three) {
        try writer.print(
            \\        .stage3 = &{s}_stage3,
            \\
        , .{prefix});
    }

    try writer.print(
        \\        .backing = &{s}_backing,
        \\    }},
        \\
    , .{prefix});
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
