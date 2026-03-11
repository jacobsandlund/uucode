const std = @import("std");
const storage = @import("storage.zig");
const config = @import("config.zig");
const build_config = @import("build_config");
const inlineAssert = config.quirks.inlineAssert;

pub const std_options: std.Options = .{
    .log_level = if (@hasDecl(build_config, "log_level"))
        build_config.log_level
    else
        .info,
};

const fields_and_unused = if (config.is_updating_ucd) &updating_ucd_fields else build_config.fields;
const unresolved_tables = if (config.is_updating_ucd) &updating_ucd_tables else build_config.tables;
const build_components_and_unused = if (config.is_updating_ucd) config.build_components else build_config.build_components;
const get_components = if (config.is_updating_ucd) config.get_components else build_config.get_components;
const all_components = build_components_and_unused ++ get_components;

fn visitField(comptime used: *[fields_and_unused.len]bool, comptime field: []const u8) void {
    @setEvalBranchQuota(50_000);
    const i = config.fieldIndex(fields_and_unused, field);
    if (!used[i]) {
        used[i] = true;
        const c = config.componentIndexFor(all_components, field);
        for (all_components[c].inputs) |input| {
            visitField(used, input);
        }
    }
}

const is_field_used = blk: {
    var used: [fields_and_unused.len]bool = @splat(false);
    for (unresolved_tables) |table| {
        for (table.fields) |f| visitField(&used, f);
    }
    for (get_components) |component| {
        for (component.inputs) |f| visitField(&used, f);
    }
    break :blk used;
};

const fields = blk: {
    var result: [fields_and_unused.len]config.Field = undefined;
    var i: usize = 0;
    for (fields_and_unused, is_field_used) |f, used| {
        if (used) {
            result[i] = f;
            i += 1;
        }
    }
    break :blk result[0..i];
};

const field_names = blk: {
    var result: [fields.len][]const u8 = undefined;
    for (fields, 0..) |field, i| {
        result[i] = field.name;
    }
    break :blk &result;
};

const row_fields_and_backing = blk: {
    var result: [fields.len]usize = undefined;
    var i: usize = 0;
    for (fields, 0..) |field, f| {
        const c = config.componentIndexFor(all_components, field.name);
        const component = all_components[c];
        if (@hasDecl(component, "build")) {
            result[i] = f;
            i += 1;
        }
    }
    break :blk result[0..i];
};

const row_fields = blk: {
    var result: [row_fields_and_backing.len]usize = undefined;
    var i: usize = 0;
    for (row_fields_and_backing) |f| {
        const field = fields[f].name;
        const c = config.componentIndexFor(build_components_and_unused, field);
        const component = build_components_and_unused[c];
        const is_row_field = for (component.fields) |cfield| {
            if (std.mem.eql(u8, cfield, field)) break true;
        } else false;
        if (is_row_field) {
            result[i] = f;
            i += 1;
        }
    }
    break :blk result[0..i];
};

fn visitComponentFor(comptime used: *[all_components.len]bool, comptime field: []const u8) void {
    const i = config.componentIndexFor(all_components, field);
    if (!used[i]) {
        used[i] = true;
        for (all_components[i].inputs) |input| {
            visitField(used, input);
        }
    }
}

const is_component_used = blk: {
    const used: [all_components.len]bool = @splat(false);
    for (unresolved_tables) |table| {
        for (table.fields) |f| visitComponentFor(used, f);
    }
    for (get_components) |component| {
        for (component.inputs) |f| visitComponentFor(used, f);
    }
    break :blk used;
};

const build_components = blk: {
    var result: [all_components.len]type = undefined;
    var i: usize = 0;
    for (all_components, is_component_used) |component, used| {
        if (used and @hasDecl(component, "build")) {
            result[i] = component;
            i += 1;
        }
    }
    break :blk result[0..i];
};

const tables = blk: {
    var ts: [unresolved_tables.len]config.Table = undefined;
    for (unresolved_tables, 0..) |table, i| {
        ts[i] = table.resolve(fields);
    }
    break :blk ts;
};

const fields_is_packed = blk: {
    var is_packed: [fields.len]bool = @splat(false);
    for (tables) |table| {
        if (table.packing == .@"packed") {
            for (table.fields) |field| {
                const f = config.fieldIndex(fields, field);
                is_packed[f] = true;
            }
        }
    }
    break :blk &is_packed;
};

const AllRow = config.Row(fields, fields_is_packed, row_fields);
const Backing = config.Backing(fields, fields_is_packed, row_fields_and_backing);
const Tracking = config.Tracking(fields, fields_is_packed, row_fields_and_backing);

pub fn main() !void {
    const total_start = try std.time.Instant.now();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    _ = args_iter.skip(); // Skip program name

    const output_path = args_iter.next() orelse std.debug.panic("No output file arg!", .{});

    std.log.debug("Writing to file: {s}", .{output_path});

    var rows: std.MultiArrayList(AllRow) = .empty;
    var slice = rows.slice();
    try rows.ensureTotalCapacity(allocator, config.num_code_points);
    var backing: Backing = undefined;
    var tracking: Tracking = undefined;

    inline for (build_components) |component| {
        const component_inputs = config.selectFieldIndexes(
            fields,
            component.inputs,
        );
        const component_fields = config.selectFieldIndexes(
            fields,
            component.fields,
        );
        const component_backing_only = config.selectFieldIndexes(
            fields,
            component.backing_only_fields,
        );

        const input_fields = config.intersect(row_fields, component_inputs);
        const inputs = config.multiSliceSubset(
            fields,
            fields_is_packed,
            row_fields,
            input_fields,
            slice,
        );

        const build_fields = config.intersect(component_fields, row_fields);
        const builds = config.multiSliceSubset(
            fields,
            fields_is_packed,
            row_fields,
            build_fields,
            slice,
        );

        const component_outputs = component_fields.* ++ component_backing_only.*;
        const component_union = component_inputs.* ++ component_outputs;
        const backing_fields = config.intersect(
            &component_union,
            row_fields_and_backing,
        );
        const BackingSubset = config.Backing(
            fields,
            fields_is_packed,
            backing_fields,
        );
        const backing_input_fields = config.intersect(
            row_fields_and_backing,
            component_inputs,
        );
        const backing_output_fields = config.intersect(
            row_fields_and_backing,
            &component_outputs,
        );
        const backing_inputs = config.selectAt(
            [:0]const u8,
            field_names,
            backing_input_fields,
        );
        const backing_outputs = config.selectAt(
            [:0]const u8,
            field_names,
            backing_output_fields,
        );

        const TrackingSubset = config.Tracking(
            fields,
            fields_is_packed,
            backing_fields,
        );

        inputs.len = config.num_code_points;
        var backing_subset: BackingSubset = undefined;
        var tracking_subset: TrackingSubset = undefined;
        for (backing_inputs) |input| {
            @field(backing_subset, input) = @field(backing, input);
            @field(tracking_subset, input) = @field(tracking, input);
        }

        try component.build(
            fields,
            fields_is_packed,
            input_fields,
            build_fields,
            allocator,
            inputs,
            builds,
            &backing_subset,
            &tracking_subset,
        );

        for (backing_outputs) |output| {
            @field(backing, output) = @field(backing_subset, output);
            @field(tracking, output) = @field(tracking_subset, output);
        }
    }

    rows.len = config.num_code_points;

    const build_components_end = try std.time.Instant.now();
    std.log.debug("build_components.build time: {d}ms", .{build_components_end.since(total_start) / std.time.ns_per_ms});

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    var out_buffer: [4096]u8 = undefined;
    var file_writer = out_file.writer(&out_buffer);
    var writer = &file_writer.interface;

    try writer.writeAll(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const std = @import("std");
        \\const config = @import("config.zig");
        \\const storage = @import("storage.zig");
        \\const build_config = @import("build_config");
        \\
        \\pub const get_components = build_config.get_components;
        \\
        \\pub const fields = config.selectFields(build_config.fields, &.{
        \\
    );

    var fields_okay = true;

    inline for (fields) |f| {
        try writer.print("    .{s},\n", .{f.name});
        const r = f.runtime();

        if (@hasField(Tracking, f.name)) {
            const t = @field(tracking, f.name);
            if (config.is_updating_ucd) {
                const min_config = t.minBitsConfig(r);
                if (!config.field(f.name).runtime().eql(min_config)) {
                    std.debug.print("Unequal!\n", .{});
                    var buffer: [4096]u8 = undefined;
                    var stderr_writer = std.fs.File.stderr().writer(&buffer);
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
                    fields_okay = false;
                }
            }
        }
    }

    if (!fields_okay) {
        @panic("Field config doesn't match actual. See above for details");
    }

    try writer.writeAll(
        \\});
        \\
        \\const fields_is_packed: []const bool = &.{
        \\
    );

    for (fields_is_packed) |is_packed| {
        try writer.print("{},", .{is_packed});
    }

    try writer.writeAll(
        \\
        \\};
        \\
        \\const row_fields_and_backing: []const usize = &.{
        \\
    );

    for (row_fields_and_backing) |f| {
        try writer.print("{},", .{f});
    }

    try writer.writeAll(
        \\
        \\};
        \\
        \\pub const Backing = config.Backing(fields, fields_is_packed, row_fields_and_backing);
        \\
    );

    inline for (@typeInfo(Backing).@"struct".fields) |field| {
        const info = @typeInfo(field.type);
        if (info != .pointer or info.pointer.size != .slice) continue;

        const T = info.pointer.child;

        try writer.print("const backing_{s}: []const {s} = ", .{
            field.name,
            @typeName(T),
        });

        const b = @field(backing, field.name);

        if (T == u8) {
            try writer.print("\"{s}\";\n", .{b});
        } else {
            try writer.writeAll("&.{");

            if (@hasDecl(T, "write")) {
                for (b) |item| {
                    try item.write(writer);
                    try writer.print(",");
                }
            } else {
                for (b) |item| {
                    try writer.print("{},", .{item});
                }
            }

            try writer.writeAll(
                \\};
                \\
            );
        }
    }

    try writer.writeAll(
        \\
        \\pub const backing: Backing = .{
        \\
    );

    inline for (@typeInfo(Backing).@"struct".fields) |field| {
        const info = @typeInfo(field.type);
        if (info == .pointer and info.pointer.size == .slice) {
            try writer.print("    .{s} = backing_{s},\n", .{
                field.name,
                field.name,
            });
        } else {
            try writer.print("    .{s} = ", .{field.name});
            try @field(backing, field.name).write(writer);
            try writer.writeAll(",\n");
        }
    }

    try writer.writeAll(
        \\};
        \\
    );

    inline for (tables, 0..) |table, i| {
        const start = try std.time.Instant.now();

        try writeTableRows(
            table,
            i,
            allocator,
            writer,
            slice,
        );

        const end = try std.time.Instant.now();
        std.log.debug("`writeTableRows` for table {d} time: {d}ms", .{ i, end.since(start) / std.time.ns_per_ms });
    }

    try writer.writeAll(
        \\
        \\pub const tables = .{
        \\
    );

    inline for (tables, 0..) |table, i| {
        if (table.name) |name| {
            try writer.print("    .{s} = ", .{name});
        } else {
            try writer.print("    .@\"{d}\" = ", .{i});
        }

        const prefix, const TypePrefix = try tablePrefix(table, i, allocator);

        if (table.stages == .three) {
            try writer.print(
                \\storage.Table3({s}_Stage1, {s}_Stage2, {s}_Row){{
                \\        .stage1 = &{s}_stage1,
                \\        .stage2 = &{s}_stage2,
                \\        .stage3 = &{s}_stage3,
                \\    }},
                \\
            , .{
                TypePrefix,
                TypePrefix,
                TypePrefix,
                prefix,
                prefix,
                prefix,
            });
        } else {
            try writer.print(
                \\storage.Table2({s}_Stage1, {s}_Row){{
                \\        .stage1 = &{s}_stage1,
                \\        .stage2 = &{s}_stage2,
                \\    }},
                \\
            , .{
                TypePrefix,
                TypePrefix,
                prefix,
                prefix,
            });
        }
    }

    try writer.writeAll(
        \\
        \\};
        \\
    );

    try writer.flush();

    std.log.debug("Arena end capacity: {d}", .{arena.queryCapacity()});

    const total_end = try std.time.Instant.now();
    std.log.debug("Total time: {d}ms", .{total_end.since(total_start) / std.time.ns_per_ms});

    if (config.is_updating_ucd) {
        @panic("Updating Ucd -- tables not configured to actully run. flip `is_updating_ucd` to false and run again");
    }
}

fn hashRow(comptime Row: type, hasher: anytype, row: Row) void {
    inline for (@typeInfo(Row).@"struct".fields) |field| {
        if (comptime @typeInfo(field.type) == .@"struct" and @hasDecl(field.type, "autoHash")) {
            @field(row, field.name).autoHash(hasher);
        } else {
            std.hash.autoHash(hasher, @field(row, field.name));
        }
    }
}

fn eqlRow(comptime Row: type, a: Row, b: Row) bool {
    inline for (@typeInfo(Row).@"struct".fields) |field| {
        if (comptime @typeInfo(field.type) == .@"struct" and @hasDecl(field.type, "eql")) {
            if (!@field(a, field.name).eql(@field(b, field.name))) {
                return false;
            }
        } else {
            if (!std.meta.eql(@field(a, field.name), @field(b, field.name))) {
                return false;
            }
        }
    }
    return true;
}

fn RowMap(comptime Row: type) type {
    return std.HashMapUnmanaged(Row, u32, struct {
        pub fn hash(self: @This(), row: Row) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(128572459);
            hashRow(Row, &hasher, row);
            return hasher.final();
        }

        pub fn eql(self: @This(), a: Row, b: Row) bool {
            _ = self;
            return eqlRow(Row, a, b);
        }
    }, std.hash_map.default_max_load_percentage);
}

const block_size = 256;

fn Block(comptime T: type) type {
    inlineAssert(T == u32 or @typeInfo(T) == .@"struct");
    return [block_size]T;
}

fn BlockMap(comptime B: type) type {
    const T = @typeInfo(B).array.child;
    return std.HashMapUnmanaged(B, u32, struct {
        pub fn hash(self: @This(), block: B) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(915296157);
            if (@typeInfo(T) == .@"struct") {
                for (block) |item| {
                    hashRow(T, &hasher, item);
                }
            } else {
                std.hash.autoHash(&hasher, block);
            }
            return hasher.final();
        }

        pub fn eql(self: @This(), a: B, b: B) bool {
            _ = self;
            if (@typeInfo(T) == .@"struct") {
                for (a, b) |a_item, b_item| {
                    if (!eqlRow(T, a_item, b_item)) {
                        return false;
                    }
                }

                return true;
            } else {
                return std.mem.eql(T, &a, &b);
            }
        }
    }, std.hash_map.default_max_load_percentage);
}

fn tablePrefix(
    comptime table: config.Table,
    table_index: usize,
    allocator: std.mem.Allocator,
) !struct { []const u8, []const u8 } {
    const prefix = if (table.name) |name|
        try std.fmt.allocPrint(allocator, "table_{s}", .{name})
    else
        try std.fmt.allocPrint(allocator, "table_{d}", .{table_index});

    const TypePrefix = if (table.name) |name|
        try std.fmt.allocPrint(allocator, "Table_{s}", .{name})
    else
        try std.fmt.allocPrint(allocator, "Table_{d}", .{table_index});

    return .{ prefix, TypePrefix };
}

pub fn writeTableRows(
    comptime table: config.Table,
    table_index: usize,
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
    slice: std.MultiArrayList(AllRow).Slice,
) !void {
    const is_packed: [table.fields.len]bool = @splat(false);
    const Row = storage.Row(
        config.selectFields(fields, table.fields),
        is_packed,
        table.packing,
    );

    const stages = table.stages;
    const num_stages: u2 = if (stages == .three) 3 else 2;

    const Stage2Elem = if (stages == .three)
        u32
    else
        Row;

    const B = Block(Stage2Elem);

    var row_map: RowMap(Row) = .empty;
    var stage3: std.ArrayListUnmanaged(Row) = .empty;
    var block_map: BlockMap(B) = .empty;
    var stage2: std.ArrayListUnmanaged(Stage2Elem) = .empty;
    var stage1: std.ArrayListUnmanaged(u32) = .empty;

    var block: B = undefined;
    var block_len: usize = 0;

    for (0..config.num_code_points) |cp| {
        // TODO: set to zero at beginning?
        var r: Row = undefined;

        inline for (table.fields) |field| {
            const sfield = comptime std.meta.stringToEnum(
                std.MultiArrayList(AllRow).Field,
                field,
            ).?;
            @field(r, field) = slice.items(sfield)[cp];
        }

        if (stages == .three) {
            const gop = try row_map.getOrPut(allocator, r);
            var row_index: u32 = undefined;
            if (gop.found_existing) {
                row_index = gop.value_ptr.*;
            } else {
                row_index = @intCast(stage3.items.len);
                gop.value_ptr.* = row_index;
                try stage3.append(allocator, r);
            }

            block[block_len] = row_index;
            block_len += 1;
        } else {
            block[block_len] = r;
            block_len += 1;
        }

        if (block_len == block_size) {
            const gop_block = try block_map.getOrPut(allocator, block);
            var block_offset: u32 = undefined;
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

    inlineAssert(block_len == 0);

    std.log.debug("Table stage 1 len: {d}", .{stage1.items.len});
    std.log.debug("Table stage 2 len: {d} (u{d})", .{ stage2.items.len, 1 + std.math.log2(stage2.items.len) });
    if (stages == .three) {
        std.log.debug("Table stage 3 len: {d} (u{d})", .{ stage3.items.len, 1 + std.math.log2(stage3.items.len) });
    }

    const prefix, const TypePrefix = try tablePrefix(table, table_index, allocator);

    try writer.print(
        \\const {s}_Row = storage.Row(
        \\    config.selectFields(
        \\        fields,
        \\        .{{
        \\
    , .{TypePrefix});

    for (table.fields) |field| {
        try writer.print("            .{s}\n", .{field});
    }

    try writer.print(
        \\        }},
        \\    ),
        \\    &@as([{d}]bool, @splat(false)),
        \\    {s},
        \\);
        \\
        \\const {s}_Stage1 = u{};
        \\
    , .{
        table.fields.len,
        if (table.packing == .@"packed") ".@\"packed\"" else ".unpacked",
        TypePrefix,
        1 + std.math.log2(stage2.items.len),
    });

    if (stages == .three) {
        try writer.print(
            \\const {s}_Stage2 = u{};
            \\
        ,
            .{
                TypePrefix,
                1 + std.math.log2(stage3.items.len),
            },
        );
    }

    try writer.print(
        \\}};
        \\
        \\const {s}_stage1: []{s}_Stage1 align(std.atomic.cache_line) = &.{{
        \\
    ,
        .{ prefix, TypePrefix },
    );

    for (stage1.items) |item| {
        try writer.print("{},", .{item});
    }

    if (stages == .three) {
        try writer.print(
            \\
            \\}};
            \\
            \\const {s}_stage2: []{s}_Stage2 align(std.atomic.cache_line) = &.{{
            \\
        ,
            .{ prefix, TypePrefix },
        );

        for (stage2.items) |item| {
            try writer.print("{},", .{item});
        }
    }

    const rows = if (stages == .three) stage3.items else stage2.items;

    try writer.writeAll(
        \\
        \\};
        \\
        \\
    );

    try writer.print(
        "const {s}_stage{d}: []{s}_Row align(@max(std.atomic.cache_line, @alignOf({s}_Row))) = ",
        .{ prefix, num_stages, TypePrefix, TypePrefix },
    );

    if (@typeInfo(Row).@"struct".layout == .@"packed") {
        const IntEquivalent = std.meta.Int(.unsigned, @bitSizeOf(Row));

        try writer.print("&@bitCast([_]{s}{{\n", .{@typeName(IntEquivalent)});

        for (rows) |row| {
            try writer.print("{d},", .{@as(IntEquivalent, @bitCast(row))});
        }

        try writer.writeAll(
            \\});
            \\
        );
    } else {
        try writer.writeAll(
            \\&.{
            \\
        );

        for (rows) |row| {
            try writer.writeAll(
                \\.{
                \\
            );

            inline for (@typeInfo(Row).@"struct".fields) |field| {
                try writer.print("    .{s} = ", .{field.name});

                try storage.writeField(field.type, writer, @field(row, field.name));

                try writer.writeAll(",\n");
            }

            try writer.writeAll(
                \\},
                \\
            );
        }

        try writer.writeAll(
            \\};
            \\
        );
    }

    try writer.writeAll(
        \\
        \\
    );
}

const updating_ucd_fields = brk: {
    const max_cp: u21 = config.max_code_point;

    @setEvalBranchQuota(5_000);
    var ucd_fields: [config.fields.len]config.Field = undefined;

    for (config.fields, 0..) |f, i| {
        switch (f.kind()) {
            .basic => {
                ucd_fields[i] = f;
            },
            .optional => {
                ucd_fields[i] = f.override(.{
                    .min_value = std.math.minInt(isize),
                    .max_value = std.math.maxInt(isize) - 1,
                });
            },
            .shift, .@"union" => {
                ucd_fields[i] = f.override(.{
                    .shift_low = -@as(isize, max_cp),
                    .shift_high = max_cp,
                });
            },
            .slice => {
                ucd_fields[i] = f.override(.{
                    .shift_low = -@as(isize, max_cp),
                    .shift_high = max_cp,
                    .max_len = if (f.max_len > 0)
                        f.max_len * 3 + 100
                    else
                        0,
                    .max_offset = f.max_offset * 3 + 1000,
                    .embedded_len = 0,
                });
            },
        }
    }

    break :brk ucd_fields;
};

const updating_ucd_tables = [_]config.Table{
    .{
        .fields = &updatingUcdFieldNames(),
    },
};

fn updatingUcdFieldNames() [updating_ucd_fields.len][:0]const u8 {
    var ucd_fields: [updating_ucd_fields.len][:0]const u8 = undefined;
    for (updating_ucd_fields, 0..) |f, i| {
        ucd_fields[i] = f.name;
    }
    return ucd_fields;
}
