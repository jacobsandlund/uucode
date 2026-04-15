const std = @import("std");
const storage = @import("storage.zig");
const multi_slice = @import("multi_slice.zig");
pub const quirks = @import("quirks.zig");
pub const components = @import("components.zig");
pub const fields = @import("fields.zig").fields;
pub const types = @import("types.zig");

pub const MultiSlice = multi_slice.MultiSlice;

pub const build_components = components.build_components;
pub const get_components = components.get_components;

pub const max_code_point = 0x10FFFF;
pub const num_code_points = max_code_point + 1;
pub const zero_width_non_joiner = 0x200C;
pub const zero_width_joiner = 0x200D;

// The `build_config.zig` needs to set:
// pub const fields: []const Field
// pub const build_components: []const Component
// pub const get_components: []const Component  // Not supported, yet
// pub const tables: []const Table

pub const Field = struct {
    name: [:0]const u8,
    type: type,

    // For Shift + Slice fields
    cp_packing: CpPacking = .direct,
    shift_low: isize = 0,
    shift_high: isize = 0,

    // For Slice fields
    max_len: usize = 0,
    max_offset: usize = 0,
    embedded_len: usize = 0,

    // For PackedOptional fields
    min_value: isize = 0,
    max_value: isize = 0,

    pub const CpPacking = enum {
        direct,
        shift,
    };

    pub const Runtime = struct {
        name: []const u8,
        type: []const u8,
        cp_packing: CpPacking,
        shift_low: isize,
        shift_high: isize,
        max_len: usize,
        max_offset: usize,
        embedded_len: usize,
        min_value: isize,
        max_value: isize,

        pub fn eql(a: Runtime, b: Runtime) bool {
            return a.cp_packing == b.cp_packing and
                a.shift_low == b.shift_low and
                a.shift_high == b.shift_high and
                a.max_len == b.max_len and
                a.max_offset == b.max_offset and
                a.embedded_len == b.embedded_len and
                a.min_value == b.min_value and
                a.max_value == b.max_value and
                std.mem.eql(u8, a.type, b.type) and
                std.mem.eql(u8, a.name, b.name);
        }

        pub fn override(self: Runtime, overrides: anytype) Runtime {
            var result: Runtime = .{
                .name = self.name,
                .type = self.type,
                .cp_packing = self.cp_packing,
                .shift_low = self.shift_low,
                .shift_high = self.shift_high,
                .max_len = self.max_len,
                .max_offset = self.max_offset,
                .embedded_len = self.embedded_len,
                .min_value = self.min_value,
                .max_value = self.max_value,
            };

            inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
                @field(result, f.name) = @field(overrides, f.name);
            }

            return result;
        }

        pub fn compareActual(self: Runtime, actual: Runtime) bool {
            var is_okay = true;

            if (self.shift_low != actual.shift_low) {
                std.log.err("Config for field '{s}' does not match actual. Set .shift_low = {d}, // change from {d}", .{ self.name, actual.shift_low, self.shift_low });
                is_okay = false;
            }

            if (self.shift_high != actual.shift_high) {
                std.log.err("Config for field '{s}' does not match actual. Set .shift_high = {d}, // change from {d}", .{ self.name, actual.shift_high, self.shift_high });
                is_okay = false;
            }

            if (self.max_len != actual.max_len) {
                std.log.err("Config for field '{s}' does not match actual. Set .max_len = {d}, // change from {d}", .{ self.name, actual.max_len, self.max_len });
                is_okay = false;
            }

            if (self.max_offset != actual.max_offset) {
                std.log.err("Config for field '{s}' does not match actual. Set .max_offset = {d}, // change from {d}", .{ self.name, actual.max_offset, self.max_offset });
                is_okay = false;
            }

            if (self.min_value != actual.min_value) {
                std.log.err("Config for field '{s}' does not match actual. Set .min_value = {d}, // change from {d}", .{ self.name, actual.min_value, self.min_value });
                is_okay = false;
            }

            if (self.max_value != actual.max_value) {
                std.log.err("Config for field '{s}' does not match actual. Set .max_value = {d}, // change from {d}", .{ self.name, actual.max_value, self.max_value });
                is_okay = false;
            }

            return is_okay;
        }

        pub fn write(self: Runtime, writer: *std.Io.Writer) !void {
            try writer.print(
                \\.{{
                \\    .name = "{s}",
                \\    .type = {s},
                \\
            , .{ self.name, self.type });

            if (self.cp_packing != .direct or
                self.shift_low != 0 or
                self.shift_high != 0)
            {
                try writer.print(
                    \\    .cp_packing = .{s},
                    \\    .shift_low = {},
                    \\    .shift_high = {},
                    \\
                , .{ @tagName(self.cp_packing), self.shift_low, self.shift_high });
            }

            if (self.max_len != 0) {
                try writer.print(
                    \\    .max_len = {},
                    \\    .max_offset = {},
                    \\    .embedded_len = {},
                    \\
                , .{ self.max_len, self.max_offset, self.embedded_len });
            }

            if (self.min_value != 0 or self.max_value != 0) {
                try writer.print(
                    \\    .min_value = {},
                    \\    .max_value = {},
                    \\
                , .{ self.min_value, self.max_value });
            }

            try writer.writeAll(
                \\},
                \\
            );
        }
    };

    pub const Kind = enum {
        basic,
        slice,
        shift,
        optional,
        @"union",
    };

    pub inline fn isOptional(self: Field) bool {
        return @typeInfo(self.type) == .optional;
    }

    pub fn validate(comptime self: Field) void {
        switch (self.kind()) {
            .shift => {
                switch (@typeInfo(self.type)) {
                    .optional => |optional| {
                        if (optional.child != u21) {
                            @compileError("Shift field '" ++ self.name ++ "' must be type ?u21");
                        }
                    },
                    .int => {
                        if (self.type != u21) {
                            @compileError("Shift field '" ++ self.name ++ "' must be type u21");
                        }
                    },
                    else => unreachable,
                }
            },
            .slice => {
                if (self.cp_packing == .shift) {
                    if (@typeInfo(self.type).pointer.child != u21) {
                        @compileError("Slice field '" ++ self.name ++ "' with shift packing must be type []const u21");
                    }
                }
                if (self.max_len == 0) {
                    @compileError("Slice with max_len == 0 is not supported due to Zig compiler bug");
                }

                const all_embedded = self.embedded_len == self.max_len;
                const all_shift = self.max_len == 1 and self.cp_packing == .shift;
                if (self.max_offset == 0 and !(all_embedded or all_shift)) {
                    @compileError("Slice with max_offset == 0 is only supported if embedded_len is max_len, or max_len is 1 with shift");
                }
            },
            .@"union" => {
                if (self.cp_packing == .shift) {
                    const info = @typeInfo(self.type).@"union";
                    const has_u21 = for (info.fields) |f| {
                        if (f.type == u21) break true;
                    } else false;
                    if (!has_u21) {
                        @compileError("Union field '" ++ self.name ++ "' with shift packing must have at least one u21 member");
                    }
                }
            },
            .optional => {
                if (self.min_value == 0 and self.max_value == 0) {
                    @compileError("PackedOptional field '" ++ self.name ++ "' with min_value = 0 and max_value = 0. Set to minInt(isize), maxInt(isize) - 1 and run again to get actual values");
                }
            },
            else => {},
        }
    }

    pub fn kind(self: Field) Kind {
        switch (@typeInfo(self.type)) {
            .pointer => return .slice,
            .optional => |optional| {
                if (!isPackable(optional.child)) {
                    return .basic;
                }

                switch (self.cp_packing) {
                    .direct => return .optional,
                    .shift => return .shift,
                }
            },
            .@"union" => return .@"union",
            .int => {
                switch (self.cp_packing) {
                    .direct => return .basic,
                    .shift => return .shift,
                }
            },
            else => return .basic,
        }
    }

    pub fn canBePacked(self: Field) bool {
        if (self.kind() == .slice) {
            return false;
        }

        switch (@typeInfo(self.type)) {
            .optional => |optional| {
                return isPackable(optional.child);
            },
            .@"union" => |info| {
                return for (info.fields) |f| {
                    if (f.type != void and !isPackable(f.type)) {
                        break false;
                    }
                } else true;
            },
            else => return true,
        }
    }

    pub fn runtime(self: Field) Runtime {
        return .{
            .name = self.name,
            .type = @typeName(self.type),
            .cp_packing = self.cp_packing,
            .shift_low = self.shift_low,
            .shift_high = self.shift_high,
            .max_len = self.max_len,
            .max_offset = self.max_offset,
            .embedded_len = self.embedded_len,
            .min_value = self.min_value,
            .max_value = self.max_value,
        };
    }

    pub fn eql(a: Field, b: Field) bool {
        // Use runtime `eql` just to be lazy
        return a.runtime().eql(b.runtime());
    }

    pub fn override(self: Field, overrides: anytype) Field {
        var result = self;

        inline for (@typeInfo(@TypeOf(overrides)).@"struct".fields) |f| {
            if (!is_updating_ucd and (std.mem.eql(u8, f.name, "name") or
                std.mem.eql(u8, f.name, "type") or
                std.mem.eql(u8, f.name, "shift_low") or
                std.mem.eql(u8, f.name, "shift_high") or
                std.mem.eql(u8, f.name, "max_len") or
                std.mem.eql(u8, f.name, "min_value") or
                std.mem.eql(u8, f.name, "max_value")))
            {
                @compileError("Cannot override field '" ++ f.name ++ "'");
            }

            @field(result, f.name) = @field(overrides, f.name);
        }

        return result;
    }
};

pub fn isPackable(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .int => |int| {
            return int.bits <= @bitSizeOf(isize);
        },
        .@"enum" => |e| {
            return @typeInfo(e.tag_type).int.bits <= @bitSizeOf(isize);
        },
        .bool => return true,
        else => return false,
    }
}

// This is the "interface" for a component:
//
pub const Component = struct {
    // struct type defining *either* `build` or `get`.
    //
    // // Sets the `rows` slices for the selected fields from `Row`
    // pub fn build(
    //     comptime InputRow: type,
    //     comptime Row: type,
    //     allocator: std.mem.Allocator,
    //     io: std.Io,
    //     inputs: config.MultiSlice(InputRow),
    //     rows: *config.MultiSlice(Row),
    //     backing: anytype, // Backing,
    //     tracking: anytype, // *Tracking,
    // ) config.Error!void;
    //
    // // Computes the field value at runtime from the inputs and/or backing
    // pub fn get(
    //     comptime field: Field,
    //     cp: u21,
    //     tables: anytype,
    //     backing: anytype,
    // ) field.type;
    Impl: type,

    inputs: []const [:0]const u8 = &[_][:0]const u8{},

    // These fields get built into tables, or are values derived by the
    // `get` method for `get_components`.
    fields: []const [:0]const u8,

    // Some fields need only backing, if they are used as `inputs` to
    // other components (usually in "get" components).
    backing_only_fields: []const [:0]const u8 = &[_][:0]const u8{},

    pub const Error = std.mem.Allocator.Error || std.Io.Dir.OpenError;

    fn coveredBy(comptime a: Component, comptime b: Component) bool {
        if (a.backing_only_fields.len != b.backing_only_fields.len) return false;
        for (a.backing_only_fields) |af| {
            for (b.backing_only_fields) |bf| {
                if (std.mem.eql(u8, af, bf)) break;
            } else return false;
        }

        if (a.fields.len != b.fields.len) return false;
        for (a.fields) |af| {
            for (b.fields) |bf| {
                if (std.mem.eql(u8, af.name, bf.name)) break;
            } else return false;
        }

        return true;
    }

    fn partiallyMatches(comptime self: Component, comptime fs: *[][:0]const u8, comptime backing_only: *[][:0]const u8) bool {
        @setEvalBranchQuota(10_000);
        var matches = false;
        var i: usize = 0;
        for (fs.*) |af| {
            for (self.fields) |bf| {
                if (std.mem.eql(u8, af, bf)) {
                    matches = true;
                    break;
                }
            } else {
                fs.*[i] = af;
                i += 1;
            }
        }

        fs.*.len = i;
        i = 0;

        for (backing_only.*) |af| {
            for (self.backing_only_fields) |bf| {
                if (std.mem.eql(u8, af, bf)) {
                    matches = true;
                    break;
                }
            } else {
                backing_only.*[i] = af;
                i += 1;
            }
        }

        backing_only.*.len = i;
        return matches;
    }
};

pub const Table = struct {
    name: ?[]const u8 = null,
    stages: Stages = .auto,
    packing: Packing = .auto,

    // The union of all `fields` on all tables defines what fields are
    // available for `uucode.get`. Additionally, any "get" fields from "get"
    // components are activated if any table contains all the inputs for that
    // component.
    fields: []const [:0]const u8,

    pub const Stages = enum {
        auto,
        two,
        three,
    };

    pub const Packing = enum {
        auto, // as in decide automatically, not as in Type.ContainerLayout.auto
        @"packed",
        unpacked,
    };

    // TODO: benchmark this more
    const two_stage_size_threshold = 4;

    pub fn resolve(comptime self: *const Table, comptime fields_: []const Field) Table {
        if (self.stages != .auto and self.packing != .auto) {
            return self;
        }

        const fs = selectFields(fields_, self.fields);

        const can_be_packed = switch (self.packing) {
            .auto, .@"packed" => blk: {
                for (fs) |f| {
                    if (!f.canBePacked()) {
                        break :blk false;
                    }
                }

                break :blk true;
            },
            .unpacked => false,
        };

        const fields_is_packed: [fs.len]bool = @splat(false);
        const RowUnpacked = storage.Row(&fs, &fields_is_packed, .unpacked);
        const RowPacked = if (can_be_packed)
            storage.Row(&fs, &fields_is_packed, .@"packed")
        else
            RowUnpacked;

        const unpacked_size = @sizeOf(RowUnpacked);
        const packed_size = @sizeOf(RowPacked);
        const min_size = @min(unpacked_size, packed_size);

        const stages: Stages = switch (self.stages) {
            .auto => blk: {
                if (min_size <= two_stage_size_threshold) {
                    break :blk .two;
                } else {
                    break :blk .three;
                }
            },
            .two => .two,
            .three => .three,
        };

        const packing: Packing = switch (self.packing) {
            .auto => blk: {
                if (!can_be_packed) {
                    break :blk .unpacked;
                }

                if (unpacked_size == min_size or unpacked_size <= two_stage_size_threshold) {
                    break :blk .unpacked;
                }

                if (stages == .two) {
                    if (packed_size <= two_stage_size_threshold) {
                        break :blk .@"packed";
                    } else if (3 * packed_size <= 2 * unpacked_size) {
                        break :blk .@"packed";
                    } else {
                        break :blk .unpacked;
                    }
                } else {
                    if (packed_size <= unpacked_size / 2) {
                        break :blk .@"packed";
                    } else {
                        break :blk .unpacked;
                    }
                }
            },
            .@"packed" => .@"packed",
            .unpacked => .unpacked,
        };

        return .{
            .stages = stages,
            .packing = packing,
            .name = self.name,
            .fields = self.fields,
        };
    }
};

pub fn Row(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime indexes: []const usize,
) type {
    const selected_fs = selectAt(Field, fs, indexes);
    const selected_packed = selectAt(bool, fs_is_packed, indexes);
    return storage.Row(&selected_fs, &selected_packed, .unpacked);
}

fn DeclStruct(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime selected_fields: []const usize,
    comptime decl: []const u8,
) type {
    const selected_fs = selectAt(Field, fs, selected_fields);
    const selected_packed = selectAt(bool, fs_is_packed, selected_fields);
    return storage.DeclStruct(&selected_fs, &selected_packed, decl);
}

pub fn Backing(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime backing_fields: []const usize,
) type {
    return DeclStruct(fs, fs_is_packed, backing_fields, "Backing");
}

pub fn Tracking(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime tracking_fields: []const usize,
) type {
    return DeclStruct(fs, fs_is_packed, tracking_fields, "Tracking");
}

pub fn fieldIndex(comptime fs: []const Field, comptime name: []const u8) usize {
    @setEvalBranchQuota(10_000);
    for (fs, 0..) |f, i| {
        if (std.mem.eql(u8, f.name, name)) return i;
    }
    @compileError("Field '" ++ name ++ "' not found in fields");
}

pub fn field(comptime fs: []const Field, comptime name: []const u8) Field {
    return fs[fieldIndex(fs, name)];
}

pub fn FieldFor(comptime fs: []const Field, comptime name: []const u8) type {
    return storage.Field(field(fs, name), false);
}

pub fn selectFieldIndexes(comptime fs: []const Field, comptime select: []const []const u8) [select.len]usize {
    var result: [select.len]usize = undefined;
    for (select, 0..) |f, i| {
        result[i] = fieldIndex(fs, f);
    }
    return result;
}

pub fn selectFields(comptime fs: []const Field, comptime select: []const []const u8) [select.len]Field {
    var result: [select.len]Field = undefined;
    const indexes = selectFieldIndexes(fs, select);
    for (indexes, 0..) |f, i| {
        result[i] = fs[f];
    }
    return result;
}

pub fn mergeFields(comptime a: []const Field, comptime b: []const Field) [mergeFieldsLen(a, b)]Field {
    @setEvalBranchQuota(1_000_000);
    var result: [mergeFieldsLen(a, b)]Field = undefined;
    var i: usize = 0;
    loop_a: for (a) |af| {
        for (b) |bf| {
            if (std.mem.eql(u8, af.name, bf.name)) {
                continue :loop_a;
            }
        }
        result[i] = af;
        i += 1;
    }
    for (b) |bf| {
        result[i] = bf;
        i += 1;
    }
    return result;
}

fn mergeFieldsLen(comptime a: []const Field, comptime b: []const Field) usize {
    @setEvalBranchQuota(1_000_000);
    var count: usize = b.len;
    loop_a: for (a) |af| {
        for (b) |bf| {
            if (std.mem.eql(u8, af.name, bf.name)) {
                continue :loop_a;
            }
        }
        count += 1;
    }
    return count;
}

pub fn selectAt(comptime T: type, comptime all: []const T, comptime select: []const usize) [select.len]T {
    var result: [select.len]T = undefined;
    for (select, 0..) |s, i| {
        result[i] = all[s];
    }
    return result;
}

fn intersectLen(comptime a: []const usize, comptime b: []const usize) usize {
    @setEvalBranchQuota(500_000);
    var count: usize = 0;
    for (a) |av| {
        for (b) |bv| {
            if (av == bv) {
                count += 1;
                break;
            }
        }
    }
    return count;
}

pub fn intersect(comptime a: []const usize, comptime b: []const usize) [intersectLen(a, b)]usize {
    @setEvalBranchQuota(500_000);
    var result: [intersectLen(a, b)]usize = undefined;
    var i: usize = 0;
    for (a) |av| {
        for (b) |bv| {
            if (av == bv) {
                result[i] = av;
                i += 1;
                break;
            }
        }
    }
    return result;
}

pub fn componentIndexFor(comptime cs: []const Component, comptime field_name: []const u8) usize {
    for (cs, 0..) |c, i| {
        for (c.fields) |f| {
            if (std.mem.eql(u8, f, field_name)) return i;
        }
        for (c.backing_only_fields) |f| {
            if (std.mem.eql(u8, f, field_name)) return i;
        }
    }
    @compileError("Component not found for field: " ++ field_name);
}

pub fn componentFor(comptime cs: []const Component, comptime field_name: []const u8) Component {
    @setEvalBranchQuota(10_000);
    const i = componentIndexFor(cs, field_name);
    return cs[i];
}

fn mergeComponentsLen(comptime a: []const Component, comptime b: []const Component) usize {
    var count: usize = 0;
    var bi: usize = 0;
    loop_a: for (a) |ac| {
        comptime var fs: [ac.fields.len][:0]const u8 = ac.fields[0..ac.fields.len].*;
        comptime var backing_only: [ac.backing_only_fields.len][:0]const u8 = ac.backing_only_fields[0..ac.backing_only_fields.len].*;
        comptime var fs_slice: [][:0]const u8 = &fs;
        comptime var backing_only_slice: [][:0]const u8 = &backing_only;

        for (b, 0..) |bc, j| {
            if (bc.partiallyMatches(&fs_slice, &backing_only_slice)) {
                if (j < bi) {
                    @compileError("Component (at least partially) matches a component earlier in 'b'");
                }
                count += j + 1 - bi;
                bi = j + 1;

                if (fs_slice.len == 0 and backing_only_slice.len == 0) {
                    continue :loop_a;
                }
            }
        }

        count += 1;
    }
    count += b.len - bi;
    return count;
}

pub fn mergeComponents(comptime a: []const Component, comptime b: []const Component) [mergeComponentsLen(a, b)]Component {
    var result: [mergeComponentsLen(a, b)]Component = undefined;
    var i: usize = 0;
    var bi: usize = 0;
    loop_a: for (a) |ac| {
        comptime var fs: [ac.fields.len][:0]const u8 = ac.fields[0..ac.fields.len].*;
        comptime var backing_only: [ac.backing_only_fields.len][:0]const u8 = ac.backing_only_fields[0..ac.backing_only_fields.len].*;
        comptime var fs_slice: [][:0]const u8 = &fs;
        comptime var backing_only_slice: [][:0]const u8 = &backing_only;

        for (b, 0..) |bc, j| {
            if (bc.partiallyMatches(&fs_slice, &backing_only_slice)) {
                if (j < bi) {
                    @compileLog("Found (at least partially) matching component at", j, "in 'b' when already at", bc);
                    @compileError("Component (at least partially) matches a component earlier in 'b'");
                }
                for (b[bi .. j + 1]) |c| {
                    result[i] = c;
                    i += 1;
                }
                bi = j + 1;

                if (fs_slice.len == 0 and backing_only_slice.len == 0) {
                    continue :loop_a;
                }
            }
        }

        const remaining_fields = fs_slice[0..fs_slice.len].*;
        const remaining_backing = backing_only_slice[0..backing_only_slice.len].*;

        result[i] = .{
            .Impl = ac.Impl,
            .inputs = ac.inputs,
            .fields = &remaining_fields,
            .backing_only_fields = &remaining_backing,
        };
        i += 1;
    }
    for (b[bi..]) |c| {
        result[i] = c;
        i += 1;
    }

    return result;
}

pub inline fn initBuiltField(
    comptime R: type,
    comptime name: []const u8,
    value: anytype,
) @FieldType(R, name) {
    const F = @FieldType(R, name);
    if (@typeInfo(@TypeOf(value)) == .enum_literal) {
        return @field(F, @tagName(value));
    } else {
        return value;
    }
}

pub inline fn setBuiltField(
    container: anytype,
    comptime name: []const u8,
    value: anytype,
) void {
    const R = @typeInfo(@TypeOf(container)).pointer.child;
    if (@hasField(R, name)) {
        @field(container, name) = initBuiltField(R, name, value);
    }
}

pub inline fn initField(
    comptime R: type,
    comptime name: []const u8,
    cp: u21,
    value: anytype,
    tracking: anytype,
) @FieldType(R, name) {
    const Track = @typeInfo(@TypeOf(tracking)).pointer.child;
    if (@hasField(Track, name)) {
        const FT = @FieldType(Track, name);
        if (@hasDecl(FT, "track")) {
            const params = @typeInfo(@TypeOf(FT.track)).@"fn".params;
            if (params.len == 3) {
                @field(tracking, name).track(cp, value);
            } else if (params.len == 2) {
                @field(tracking, name).track(value);
            } else {
                @compileError("Tracking `track` must take 2 or 3 parameters (including self)");
            }
        }
    }
    const F = @FieldType(R, name);
    switch (@typeInfo(F)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {
            if (@hasDecl(F, "init")) {
                const params = @typeInfo(@TypeOf(F.init)).@"fn".params;
                if (params.len == 1) {
                    return F.init(value);
                } else if (params.len == 2) {
                    return F.init(cp, value);
                } else {
                    @compileError(std.fmt.comptimePrint("initField cannot be used with container with init taking {d} parameters", .{params.len}));
                }
            } else {
                return value;
            }
        },

        .optional => return value,

        .bool,
        .int,
        .float,
        .array,
        .vector,
        => return value,
        else => @compileError("initField cannot be used with type " ++ @typeName(F)),
    }
}

pub inline fn setField(
    container: anytype,
    comptime name: []const u8,
    cp: u21,
    value: anytype,
    tracking: anytype,
) void {
    const R = @typeInfo(@TypeOf(container)).pointer.child;
    if (@hasField(R, name)) {
        @field(container, name) = initField(R, name, cp, value, tracking);
    }
}

pub inline fn initAllocField(
    comptime R: type,
    comptime name: []const u8,
    allocator: std.mem.Allocator,
    cp: u21,
    value: anytype,
    tracking: anytype,
) !@FieldType(R, name) {
    const F = @FieldType(R, name);
    switch (@typeInfo(F)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {
            if (@hasDecl(F, "init")) {
                const params = @typeInfo(@TypeOf(F.init)).@"fn".params;
                if (params.len == 3) {
                    return try .init(
                        allocator,
                        &@field(tracking, name),
                        value,
                    );
                } else if (params.len == 4) {
                    return try .init(
                        allocator,
                        &@field(tracking, name),
                        value,
                        cp,
                    );
                }
            }
        },
        else => {},
    }
    return initField(R, name, cp, value, tracking);
}

pub inline fn setAllocField(
    allocator: std.mem.Allocator,
    container: anytype,
    comptime name: []const u8,
    cp: u21,
    value: anytype,
    tracking: anytype,
) !void {
    const R = @typeInfo(@TypeOf(container)).pointer.child;
    if (@hasField(R, name)) {
        @field(container, name) = try initAllocField(R, name, allocator, cp, value, tracking);
    }
}

pub const is_updating_ucd = false;
