const std = @import("std");
const types = @import("types.zig");
pub const quirks = @import("quirks.zig");
const components = @import("components.zig");
pub const fields = @import("fields.zig").fields;

pub const build_components = components.build_components;
pub const get_components = components.get_components;

pub const max_code_point = 0x10FFFF;
pub const num_code_points = max_code_point + 1;
pub const zero_width_non_joiner = 0x200C;
pub const zero_width_joiner = 0x200D;

// The `build_config.zig` needs to set:
// pub const fields: [_]Field
// pub const tables: [_]Table
// pub const build_components: [_]Component
// pub const get_components: [_]Component

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

    // For custom fields
    MutableBacking: ?type = null,
    Backing: ?type = null,
    Tracking: ?type = null,

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
    };

    pub const Kind = enum {
        basic,
        slice,
        shift,
        optional,
        @"union",
    };

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
            else => {
                switch (self.cp_packing) {
                    .direct => return .basic,
                    .shift => return .shift,
                }
            },
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
    //     comptime fields: []const config.Field,
    //     comptime fields_is_packed: []const bool,
    //     comptime input_fields: []const usize,
    //     comptime build_fields: []const usize,
    //     allocator: std.mem.Allocator,
    //     inputs: config.MultiSlice(fields, fields_is_packed, input_fields),
    //     rows: config.MultiSlice(fields, fields_is_packed, build_fields),
    //     backing: anytype, // Backing,
    //     tracking: anytype, // Tracking,
    // ) config.Error!void;
    //
    // // Computes the field value at runtime from the inputs and/or backing
    // pub fn get(
    //     comptime fields: []const Field,
    //     comptime field: []const u8,
    //     cp: u21,
    //     tables: anytype,
    //     backing: anytype,
    // ) config.FieldFor(fields, field);
    Impl: type,

    inputs: []const [:0]const u8 = &[_][:0]const u8{},

    // These fields get built into tables, or are values derived by the
    // `get` method for `get_components`.
    fields: []const [:0]const u8,

    // Some fields need only backing, if they are used as `inputs` to
    // other components (usually in "get" components).
    backing_only_fields: []const [:0]const u8 = &[_][:0]const u8{},

    pub const Error = std.mem.Allocator.Error || std.fs.File.OpenError;

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
        const RowUnpacked = types.Row(fs, fields_is_packed, .unpacked);
        const RowPacked = if (can_be_packed)
            types.Row(fs, fields_is_packed, .@"packed")
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
    return types.Row(
        selectAt(Field, fs, indexes),
        selectAt(bool, fs_is_packed, indexes),
        .unpacked,
    );
}

fn MultiArray(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime selected_fields: []const usize,
) type {
    return std.MultiArrayList(Row(fs, fs_is_packed, selected_fields));
}

pub fn MultiSlice(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime selected_fields: []const usize,
) type {
    return MultiArray(fs, fs_is_packed, selected_fields).Slice;
}

fn DeclStruct(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime selected_fields: []const usize,
    comptime decl: []const u8,
) type {
    return types.DeclStruct(
        selectAt(Field, fs, selected_fields),
        selectAt(bool, fs_is_packed, selected_fields),
        decl,
    );
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

pub fn multiSliceSubset(
    comptime fs: []const Field,
    comptime fs_is_packed: []const bool,
    comptime array_fields: []const usize,
    comptime subset_fields: []const usize,
    source: MultiSlice(fs, fs_is_packed, array_fields),
) MultiSlice(fs, fs_is_packed, subset_fields) {
    const subset_positions = comptime blk: {
        var positions: [subset_fields.len]usize = undefined;
        for (subset_fields, 0..) |sf, i| {
            positions[i] = for (array_fields, 0..) |af, j| {
                if (af == sf) break j;
            } else {
                @compileError("subset field not found in array fields");
            };
        }
        break :blk positions;
    };

    var result: MultiSlice(fs, fs_is_packed, subset_fields) = undefined;
    inline for (subset_positions, 0..) |src_idx, dst_idx| {
        result.ptrs[dst_idx] = source.ptrs[src_idx];
    }
    result.len = source.len;
    result.capacity = source.capacity;
    return result;
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
    return types.Field(field(fs, name), false);
}

pub fn selectFieldIndexes(comptime fs: []const Field, comptime select: []const []const u8) []const usize {
    var result: [select.len]usize = undefined;
    for (select, 0..) |f, i| {
        result[i] = fieldIndex(fs, f);
    }
    return &result;
}

pub fn selectFields(comptime fs: []const Field, comptime select: []const []const u8) []const Field {
    var result: [select.len]Field = undefined;
    const indexes = selectFieldIndexes(fs, select);
    for (indexes, 0..) |f, i| {
        result[i] = fs[f];
    }
    return &result;
}

pub fn mergeFields(comptime a: []const Field, comptime b: []const Field) []const Field {
    var result: [a.len + b.len]Field = undefined;
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

    return result[0..i];
}

pub fn selectAt(comptime T: type, all: []const T, select: []const usize) []const T {
    var result: [select]T = undefined;
    for (select, 0..) |s, i| {
        result[i] = all[s];
    }
    return &result;
}

pub fn intersect(comptime a: []const usize, comptime b: []const usize) []const usize {
    var result: [if (a.len < b.len) a.len else b.len]usize = undefined;
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
    return result[0..i];
}

pub fn componentIndexFor(comptime cs: []const Component, comptime field_name: []const u8) usize {
    for (cs, 0..) |c, i| {
        for (c.fields) |f| {
            if (std.mem.eql(u8, f, field_name)) return i;
        }
        if (@hasDecl(c, "backing_only_fields")) {
            for (c.backing_only_fields) |f| {
                if (std.mem.eql(u8, f, field_name)) return i;
            }
        }
    }
    @compileError("Component not found for field: " ++ field_name);
}

pub fn componentFor(comptime cs: []const Component, comptime field_name: []const u8) Component {
    @setEvalBranchQuota(10_000);
    const i = componentIndexFor(cs, field_name);
    return cs[i];
}

pub fn mergeComponents(comptime a: []const Component, comptime b: []const Component) []const Component {
    var result: [a.len + b.len]Component = undefined;
    var i: usize = 0;
    var bi: usize = 0;
    loop_a: for (a) |ac| {
        comptime var fs: [ac.fields.len][:0]const u8 = ac.fields.*;
        comptime var backing_only: [ac.backing_only_fields.len][:0]const u8 = ac.backing_only_fields.*;
        comptime var fs_slice = &fs;
        comptime var backing_only_slice = &backing_only;

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

        result[i] = .{
            .Impl = ac.Impl,
            .inputs = ac.inputs,
            .fields = fs_slice,
            .backing_only_fields = backing_only_slice,
        };
        i += 1;
    }
    for (b[bi..]) |c| {
        result[i] = c;
        i += 1;
    }

    return result[0..i];
}

pub inline fn setField(container: anytype, comptime name: []const u8, value: anytype) void {
    const T = @TypeOf(container);
    if (@hasField(T, name)) {
        @field(container, name) = value;
    }
}

pub const is_updating_ucd = false;
