const std = @import("std");
const inlineAssert = @import("config.zig").quirks.inlineAssert;

/// A replacement for std.MultiArrayList(T).Slice that supports `append`,
/// `subset` extraction, handles 0-field structs, and avoids branch quota
/// issues with large structs.
pub fn MultiSlice(comptime T: type) type {
    @setEvalBranchQuota(50_000);
    const fields = std.meta.fields(T);

    return struct {
        ptrs: [fields.len][*]u8,
        len: usize,
        capacity: usize,

        const Self = @This();
        pub const Elem = T;
        pub const Field = std.meta.FieldEnum(T);

        pub fn FieldType(comptime field: Field) type {
            @setEvalBranchQuota(50_000);
            return std.meta.fieldInfo(T, field).type;
        }

        pub fn items(self: Self, comptime field: Field) []FieldType(field) {
            const F = FieldType(field);
            if (self.capacity == 0) {
                return &[_]F{};
            }
            const byte_ptr = self.ptrs[@intFromEnum(field)];
            const casted_ptr: [*]F = if (@sizeOf(F) == 0)
                undefined
            else
                @ptrCast(@alignCast(byte_ptr));
            return casted_ptr[0..self.len];
        }

        pub fn set(self: Self, index: usize, elem: T) void {
            inline for (fields, 0..) |field_info, i| {
                self.items(@as(Field, @enumFromInt(i)))[index] = @field(elem, field_info.name);
            }
        }

        pub fn get(self: Self, index: usize) T {
            var result: T = undefined;
            inline for (fields, 0..) |field_info, i| {
                @field(result, field_info.name) = self.items(@as(Field, @enumFromInt(i)))[index];
            }
            return result;
        }

        pub fn subset(self: Self, comptime Subset: type) MultiSlice(Subset) {
            const subset_fields = std.meta.fields(Subset);
            var result: MultiSlice(Subset) = undefined;
            inline for (subset_fields, 0..) |sf, dst_idx| {
                const src_idx = comptime for (fields, 0..) |f, i| {
                    if (std.mem.eql(u8, f.name, sf.name)) break i;
                } else @compileError("subset field '" ++ sf.name ++ "' not found in source");
                result.ptrs[dst_idx] = self.ptrs[src_idx];
            }
            result.len = self.len;
            result.capacity = self.capacity;
            return result;
        }

        pub fn memset(self: Self, elem: T) void {
            inline for (fields, 0..) |field_info, i| {
                const field: Field = @enumFromInt(i);
                const value = @field(elem, field_info.name);
                const F = field_info.type;
                const slice = self.items(field);
                if (@sizeOf(F) == 0) {
                    // Zero-size types have nothing to set.
                } else if (@bitSizeOf(F) != @sizeOf(F) * 8) {
                    // Types like bool, u3, or enum(u2) have fewer bits than
                    // their storage size, so @memset can't be called directly
                    // on their slices. Convert to a byte-array representation
                    // by zero-extending into a storage-sized int, then @memset
                    // the reinterpreted byte array for the same performance as
                    // a normal @memset.
                    const StorageInt = std.meta.Int(.unsigned, @sizeOf(F) * 8);
                    const storage: StorageInt = switch (@typeInfo(F)) {
                        .int => @intCast(value),
                        .bool => @intFromBool(value),
                        .@"enum" => @intFromEnum(value),
                        else => @compileError("memset: unsupported non-byte-aligned type '" ++ @typeName(F) ++ "'"),
                    };
                    const ints: [*]StorageInt = @ptrCast(slice.ptr);
                    @memset(ints[0..slice.len], storage);
                } else {
                    @memset(slice, value);
                }
            }
        }

        pub fn append(self: *Self, elem: T) void {
            inlineAssert(self.len < self.capacity);
            self.len += 1;
            self.set(self.len - 1, elem);
        }

        pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) std.mem.Allocator.Error!Self {
            if (fields.len == 0 or capacity == 0) {
                return .{ .ptrs = undefined, .len = 0, .capacity = capacity };
            }
            const byte_count = capacityInBytes(capacity);
            const buf = try allocator.alignedAlloc(u8, alignment, byte_count);
            var result: Self = .{ .ptrs = undefined, .len = 0, .capacity = capacity };
            var ptr: [*]u8 = buf.ptr;
            for (sorted_sizes, sorted_fields) |field_size, fi| {
                result.ptrs[fi] = ptr;
                ptr += field_size * capacity;
            }
            return result;
        }

        const alignment: std.mem.Alignment = blk: {
            var max_align: usize = 1;
            for (fields) |field_info| {
                const a: usize = if (@sizeOf(field_info.type) == 0)
                    1
                else
                    field_info.alignment orelse @alignOf(field_info.type);
                if (a > max_align) max_align = a;
            }
            break :blk @enumFromInt(std.math.log2(max_align));
        };

        const sorted_sizes: [fields.len]usize = blk: {
            var sizes: [fields.len]usize = undefined;
            for (sortOrder(), 0..) |si, i| {
                sizes[i] = @sizeOf(fields[si].type);
            }
            break :blk sizes;
        };

        const sorted_fields: [fields.len]usize = sortOrder();

        fn sortOrder() [fields.len]usize {
            @setEvalBranchQuota(fields.len * fields.len + 100);
            var order: [fields.len]usize = undefined;
            for (0..fields.len) |i| order[i] = i;
            for (0..fields.len) |i| {
                var best = i;
                for (i + 1..fields.len) |j| {
                    const best_align = if (@sizeOf(fields[order[best]].type) == 0)
                        1
                    else
                        fields[order[best]].alignment orelse @alignOf(fields[order[best]].type);
                    const j_align = if (@sizeOf(fields[order[j]].type) == 0)
                        1
                    else
                        fields[order[j]].alignment orelse @alignOf(fields[order[j]].type);
                    if (j_align > best_align) best = j;
                }
                const tmp = order[i];
                order[i] = order[best];
                order[best] = tmp;
            }
            return order;
        }

        fn capacityInBytes(capacity: usize) usize {
            var total: usize = 0;
            for (sorted_sizes) |s| {
                total += s * capacity;
            }
            return total;
        }
    };
}

test "basic MultiSlice operations" {
    const Row = struct {
        a: u32,
        b: u8,
    };
    const MS = MultiSlice(Row);

    var ms = try MS.initCapacity(std.testing.allocator, 4);
    defer std.testing.allocator.free(@as([*]u8, @ptrCast(@alignCast(ms.ptrs[MS.sorted_fields[0]])))[0..MS.capacityInBytes(4)]);

    try std.testing.expectEqual(0, ms.len);

    ms.append(.{ .a = 10, .b = 1 });
    ms.append(.{ .a = 20, .b = 2 });

    try std.testing.expectEqual(2, ms.len);
    try std.testing.expectEqual(10, ms.items(.a)[0]);
    try std.testing.expectEqual(20, ms.items(.a)[1]);
    try std.testing.expectEqual(1, ms.items(.b)[0]);
    try std.testing.expectEqual(2, ms.items(.b)[1]);

    const row = ms.get(0);
    try std.testing.expectEqual(10, row.a);
    try std.testing.expectEqual(1, row.b);

    ms.set(0, .{ .a = 99, .b = 9 });
    try std.testing.expectEqual(99, ms.items(.a)[0]);
}

test "memset" {
    const Row = struct {
        a: u32,
        b: u8,
    };
    const MS = MultiSlice(Row);

    var ms = try MS.initCapacity(std.testing.allocator, 4);
    defer std.testing.allocator.free(@as([*]u8, @ptrCast(@alignCast(ms.ptrs[MS.sorted_fields[0]])))[0..MS.capacityInBytes(4)]);

    ms.len = 4;
    ms.memset(.{ .a = 42, .b = 7 });

    for (0..4) |i| {
        try std.testing.expectEqual(42, ms.items(.a)[i]);
        try std.testing.expectEqual(7, ms.items(.b)[i]);
    }

    ms.memset(.{ .a = 0, .b = 255 });
    try std.testing.expectEqual(0, ms.items(.a)[0]);
    try std.testing.expectEqual(255, ms.items(.b)[0]);
}

test "memset bool field" {
    const Row = struct {
        a: bool,
        b: u8,
    };
    const MS = MultiSlice(Row);

    var ms = try MS.initCapacity(std.testing.allocator, 4);
    defer std.testing.allocator.free(@as([*]u8, @ptrCast(@alignCast(ms.ptrs[MS.sorted_fields[0]])))[0..MS.capacityInBytes(4)]);

    ms.len = 4;
    ms.memset(.{ .a = true, .b = 7 });

    for (0..4) |i| {
        try std.testing.expectEqual(true, ms.items(.a)[i]);
        try std.testing.expectEqual(7, ms.items(.b)[i]);
    }

    ms.memset(.{ .a = false, .b = 0 });
    try std.testing.expectEqual(false, ms.items(.a)[0]);
    try std.testing.expectEqual(0, ms.items(.b)[0]);
}

test "memset small int field" {
    const Row = struct {
        a: u3,
        b: u8,
    };
    const MS = MultiSlice(Row);

    var ms = try MS.initCapacity(std.testing.allocator, 4);
    defer std.testing.allocator.free(@as([*]u8, @ptrCast(@alignCast(ms.ptrs[MS.sorted_fields[0]])))[0..MS.capacityInBytes(4)]);

    ms.len = 4;
    ms.memset(.{ .a = 5, .b = 7 });

    for (0..4) |i| {
        try std.testing.expectEqual(@as(u3, 5), ms.items(.a)[i]);
        try std.testing.expectEqual(7, ms.items(.b)[i]);
    }

    ms.memset(.{ .a = 0, .b = 0 });
    try std.testing.expectEqual(@as(u3, 0), ms.items(.a)[0]);
}

test "memset small enum field" {
    const Color = enum(u2) { red, green, blue };
    const Row = struct {
        a: Color,
        b: u8,
    };
    const MS = MultiSlice(Row);

    var ms = try MS.initCapacity(std.testing.allocator, 4);
    defer std.testing.allocator.free(@as([*]u8, @ptrCast(@alignCast(ms.ptrs[MS.sorted_fields[0]])))[0..MS.capacityInBytes(4)]);

    ms.len = 4;
    ms.memset(.{ .a = .blue, .b = 7 });

    for (0..4) |i| {
        try std.testing.expectEqual(Color.blue, ms.items(.a)[i]);
        try std.testing.expectEqual(7, ms.items(.b)[i]);
    }

    ms.memset(.{ .a = .red, .b = 0 });
    try std.testing.expectEqual(Color.red, ms.items(.a)[0]);
}

test "zero-field struct" {
    const Empty = struct {};
    const MS = MultiSlice(Empty);

    var ms = try MS.initCapacity(std.testing.allocator, 4);
    try std.testing.expectEqual(0, ms.len);

    ms.append(.{});
    try std.testing.expectEqual(1, ms.len);
}
