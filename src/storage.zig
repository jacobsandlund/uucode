const std = @import("std");
const config = @import("config.zig");

const inlineAssert = config.quirks.inlineAssert;
const Allocator = std.mem.Allocator;

pub fn RoundedInt(comptime signedness: std.builtin.Signedness, comptime bit_count: u16) type {
    const rounded_bits = std.mem.alignForward(u16, if (bit_count == 0) 1 else bit_count, 8);
    return std.meta.Int(signedness, rounded_bits);
}

pub fn RoundedIntFitting(comptime from: comptime_int, comptime to: comptime_int) type {
    const Fitting = std.math.IntFittingRange(from, to);
    const info = @typeInfo(Fitting).int;
    return RoundedInt(info.signedness, info.bits);
}

pub fn ShiftInt(
    comptime shift_low: isize,
    comptime shift_high: isize,
    comptime is_optional: bool,
    comptime is_packed: bool,
) type {
    const high = shift_high + @intFromBool(is_optional);
    if (is_packed) {
        return std.math.IntFittingRange(shift_low, high);
    } else {
        return RoundedIntFitting(shift_low, high);
    }
}

pub fn Field(comptime c: config.Field, comptime is_packed: bool) type {
    const is_optional = c.isOptional();
    const _ShiftInt = if (c.cp_packing == .shift)
        ShiftInt(
            c.shift_low,
            c.shift_high,
            is_optional,
            is_packed,
        )
    else
        void;

    switch (c.kind()) {
        .slice => {
            if (is_packed) unreachable;

            const Offset = RoundedIntFitting(0, c.max_offset);
            const Len = RoundedIntFitting(0, c.max_len);
            return Slice(
                @typeInfo(c.type).pointer.child,
                Offset,
                Len,
                _ShiftInt,
                c.embedded_len,
            );
        },
        .shift => {
            return Shift(_ShiftInt, is_optional, is_packed);
        },
        .@"union" => return Union(c.type, _ShiftInt, is_packed),
        .optional => return if (is_packed) PackedOptional(
            @typeInfo(c.type).optional.child,
            std.math.IntFittingRange(c.min_value, c.max_value + 1),
        ) else c.type,
        .basic => return c.type,
    }
}

pub fn Row(
    comptime fields: []const config.Field,
    comptime fields_is_packed: []const bool,
    comptime table_packing: config.Table.Packing,
) type {
    @setEvalBranchQuota(50_000);
    var field_names: [fields.len][]const u8 = undefined;
    var field_types: [fields.len]type = undefined;
    var field_attrs: [fields.len]std.builtin.Type.StructField.Attributes = undefined;

    for (fields, fields_is_packed, 0..) |field, is_field_packed, i| {
        const F = Field(field, is_field_packed or table_packing == .@"packed");
        field_names[i] = field.name;
        field_types[i] = F;
        field_attrs[i] = .{
            .@"comptime" = false,
            .@"align" = if (table_packing == .@"packed") null else @alignOf(F),
        };
    }

    return @Struct(
        if (table_packing == .@"packed") .@"packed" else .auto,
        null,
        &field_names,
        &field_types,
        &field_attrs,
    );
}

pub fn DeclStruct(
    comptime fields: []const config.Field,
    comptime fields_is_packed: []const bool,
    comptime decl: []const u8,
) type {
    @setEvalBranchQuota(fields.len * 100 + 1000);
    var field_names: [fields.len][]const u8 = undefined;
    var field_types: [fields.len]type = undefined;
    var field_attrs: [fields.len]std.builtin.Type.StructField.Attributes = undefined;
    var i: usize = 0;

    for (fields, fields_is_packed) |field, is_field_packed| {
        const F = Field(field, is_field_packed);
        switch (@typeInfo(F)) {
            .@"struct", .@"union", .@"enum", .@"opaque" => {
                if (@hasDecl(F, decl)) {
                    const DeclType = @field(F, decl);
                    field_names[i] = field.name;
                    field_types[i] = DeclType;
                    field_attrs[i] = .{
                        .@"comptime" = false,
                        .@"align" = @alignOf(DeclType),
                    };
                    i += 1;
                }
            },
            else => {},
        }
    }

    return @Struct(
        .auto,
        null,
        field_names[0..i],
        field_types[0..i],
        field_attrs[0..i],
    );
}

pub fn writeField(comptime F: type, writer: *std.Io.Writer, field: F) !void {
    switch (@typeInfo(F)) {
        .@"struct" => {
            if (@hasDecl(F, "write")) {
                try field.write(writer);
            } else {
                try writer.print("{}", .{field});
            }
        },
        .@"enum" => {
            if (std.enums.tagName(F, field)) |name| {
                try writer.print(".{s}", .{name});
            } else {
                try writer.print("@enumFromInt({d})", .{field});
            }
        },
        .optional => {
            try writer.print("{?}", .{field});
        },
        .@"union" => {
            switch (field) {
                inline else => |v, tag| {
                    if (@typeInfo(@TypeOf(v)) == .void) {
                        try writer.print(".{s}", .{@tagName(tag)});
                    } else {
                        try writer.print("{}", .{field});
                    }
                },
            }
        },
        else => {
            try writer.print("{}", .{field});
        },
    }
}

pub fn Table3(
    comptime Stage1: type,
    comptime Stage2: type,
    comptime Row_: type,
) type {
    return struct {
        stage1: []const Stage1,
        stage2: []const Stage2,
        stage3: []const Row_,
    };
}

pub fn Table2(
    comptime Stage1: type,
    comptime Row_: type,
) type {
    return struct {
        stage1: []const Stage1,
        stage2: []const Row_,
    };
}

pub fn Slice(
    comptime T: type,
    comptime Offset: type,
    comptime Len: type,
    comptime _ShiftInt: type,
    comptime embedded_len: usize,
) type {
    const is_shift = _ShiftInt != void;

    return struct {
        data: union {
            offset: Offset,
            embedded: [embedded_len]T,
            shift: ShiftSingleItem,
        },
        len: Len,

        const Self = @This();
        const ShiftSingleItem = if (is_shift)
            Shift(_ShiftInt, false, false)
        else
            void;

        pub const Tracking = SliceTracking(T);
        pub const Backing = []const T;
        pub const empty = if (embedded_len == 0)
            Self{ .len = 0, .data = .{ .offset = 0 } }
        else
            Self{
                .len = 0,
                .data = .{
                    .embedded = @splat(switch (@typeInfo(T)) {
                        .@"enum" => @enumFromInt(0),
                        else => 0,
                    }),
                },
            };
        pub const same = if (is_shift) Self{
            .data = .{ .shift = .same },
            .len = 1,
        } else void{};

        inline fn initInner(
            allocator: Allocator,
            tracking: *Tracking,
            s: []const T,
        ) Allocator.Error!Self {
            tracking.max_len = @max(tracking.max_len, s.len);

            if ((comptime embedded_len == 0) or s.len > embedded_len) {
                if (s.len == 0) {
                    return .empty;
                }

                const len: Len = @intCast(s.len);
                const gop = try tracking.offset_map.getOrPut(allocator, s);

                if (gop.found_existing) {
                    return .{
                        .len = len,
                        .data = .{
                            .offset = @intCast(gop.value_ptr.*),
                        },
                    };
                }

                const offset = tracking.backing.items.len;
                gop.value_ptr.* = offset;
                tracking.backing.appendSliceAssumeCapacity(s);
                gop.key_ptr.* = tracking.backing.items[offset .. offset + s.len];
                tracking.len_counts[s.len - 1] += 1;

                return .{
                    .len = len,
                    .data = .{
                        .offset = @intCast(offset),
                    },
                };
            } else {
                var embedded: [embedded_len]T = undefined;
                @memcpy(embedded[0..s.len], s);
                switch (@typeInfo(T)) {
                    .@"struct" => {
                        @memset(embedded[s.len..], 0);
                    },
                    .@"enum" => {
                        @memset(embedded[s.len..], @enumFromInt(0));
                    },
                    else => {
                        @memset(embedded[s.len..], 0);
                    },
                }

                return .{
                    .len = @intCast(s.len),
                    .data = .{
                        .embedded = embedded,
                    },
                };
            }
        }

        pub fn _init(
            allocator: Allocator,
            tracking: *Tracking,
            s: []const T,
        ) Allocator.Error!Self {
            if (is_shift) {
                @compileError("init is only supported for direct packing: use initFor instead");
            }

            return .initInner(allocator, tracking, s);
        }

        fn _initShift(
            allocator: Allocator,
            tracking: *Tracking,
            s: []const T,
            cp: u21,
        ) Allocator.Error!Self {
            if (s.len == 1) {
                tracking.shift.track(cp, s[0]);
            }

            if (is_shift and s.len == 1) {
                tracking.max_len = @max(tracking.max_len, 1);

                return .{
                    .len = 1,
                    .data = .{
                        .shift = .init(cp, s[0]),
                    },
                };
            } else {
                return .initInner(allocator, tracking, s);
            }
        }

        pub const init = if (is_shift)
            _initShift
        else
            _init;

        fn _value(
            self: *const Self,
            backing: Backing,
        ) []const T {
            if (comptime @sizeOf(Offset) == 0) {
                return self.data.embedded[0..self.len];
            } else if (comptime embedded_len == 0) {
                return backing[self.data.offset .. @as(usize, self.data.offset) + @as(usize, self.len)];
            } else if (self.len <= embedded_len) {
                return self.data.embedded[0..self.len];
            } else {
                return backing[self.data.offset .. @as(usize, self.data.offset) + @as(usize, self.len)];
            }
        }

        pub const value = if (is_shift)
            void{}
        else
            _value;

        fn _valueWith(
            self: *const Self,
            backing: Backing,
            single_item_buffer: *[1]T,
            cp: u21,
        ) []const T {
            if ((comptime is_shift) and self.len == 1) {
                single_item_buffer[0] = self.data.shift.unshift(cp);
                return single_item_buffer[0..1];
            } else {
                return self._value(backing);
            }
        }

        pub const valueWith = if (T == u21)
            _valueWith
        else
            void{};

        pub fn autoHash(self: Self, hasher: anytype) void {
            std.hash.autoHash(hasher, self.len);
            if ((comptime is_shift) and self.len == 1) {
                std.hash.autoHash(hasher, self.data.shift);
            } else if ((comptime embedded_len == 0) or self.len > embedded_len) {
                std.hash.autoHash(hasher, self.data.offset);
            } else {
                std.hash.autoHash(hasher, self.data.embedded);
            }
        }

        pub fn eql(a: Self, b: Self) bool {
            if (a.len != b.len) {
                return false;
            }
            if ((comptime is_shift) and a.len == 1) {
                return a.data.shift.eql(b.data.shift);
            } else if ((comptime embedded_len == 0) or a.len > embedded_len) {
                return a.data.offset == b.data.offset;
            } else {
                return std.mem.eql(T, &a.data.embedded, &b.data.embedded);
            }
        }

        pub fn write(self: Self, writer: *std.Io.Writer) !void {
            if ((comptime is_shift) and self.len == 1) {
                if (self.eql(.same)) {
                    try writer.writeAll(".same");
                } else {
                    try writer.print(
                        \\.{{
                        \\    .len = {},
                        \\    .data = .{{ .shift =
                    , .{self.len});
                    try self.data.shift.write(writer);
                    try writer.writeAll(
                        \\},
                        \\}
                        \\
                    );
                }
            } else if ((comptime embedded_len == 0) or self.len > embedded_len) {
                if (self.eql(.empty)) {
                    try writer.writeAll(".empty");
                } else {
                    try writer.print(
                        \\.{{
                        \\    .len = {},
                        \\    .data = .{{ .offset = {} }},
                        \\}}
                        \\
                    , .{ self.len, self.data.offset });
                }
            } else {
                if (self.eql(.empty)) {
                    try writer.writeAll(".empty");
                } else {
                    try writer.print(
                        \\.{{
                        \\    .len = {},
                        \\    .data = .{{ .embedded = .{{
                    , .{self.len});
                    for (self.data.embedded) |item| {
                        try writeField(T, writer, item);
                        try writer.writeAll(",");
                    }
                    try writer.writeAll(
                        \\} },
                        \\}
                        \\
                    );
                }
            }
        }
    };
}

fn basicTrackingOkay(tracking: anytype, comptime field: config.Field) !bool {
    const r = field.runtime();
    if (config.is_updating_ucd) {
        const min_config = tracking.minBitsConfig(r);
        if (!config.field(config.fields, field.name).runtime().eql(min_config)) {
            std.debug.print("\nUnequal!\n", .{});
            var buffer: [4096]u8 = undefined;
            var stderr_writer = std.Io.File.stderr().writer(&buffer);
            var w = &stderr_writer.interface;
            try w.writeAll(
                \\
                \\Update default config in `config.zig` with the correct field config:
                \\
            );
            try min_config.write(w);
            try w.flush();
            return false;
        }
    } else {
        if (!r.compareActual(tracking.actualConfig(r))) {
            return false;
        }
    }

    return true;
}

pub fn SliceTracking(comptime T: type) type {
    return struct {
        backing: std.ArrayList(T),
        len_counts: []usize,
        max_len: usize = 0,
        offset_map: SliceMap(T, usize) = .empty,
        shift: ShiftTracking = .{},

        const Self = @This();

        pub fn init(allocator: Allocator, field: config.Field) !Self {
            const len_counts = try allocator.alloc(usize, field.max_len);
            @memset(len_counts, 0);
            return .{
                .backing = try std.ArrayList(T).initCapacity(allocator, field.max_offset),
                .len_counts = len_counts,
            };
        }

        pub fn toOwnedBacking(self: *Self, allocator: Allocator) ![]T {
            return self.backing.toOwnedSlice(allocator);
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.backing.deinit(allocator);
            self.offset_map.deinit(allocator);
        }

        pub fn okay(self: *const Self, comptime field: config.Field) !bool {
            return basicTrackingOkay(self, field);
        }

        pub fn actualConfig(
            self: *const Self,
            c: config.Field.Runtime,
        ) config.Field.Runtime {
            return c.override(.{
                .shift_low = self.shift.shift_low,
                .shift_high = self.shift.shift_high,
                .max_len = self.max_len,
                .max_offset = self.backing.items.len,
            });
        }

        pub fn minBitsConfig(
            self: *const Self,
            c: config.Field.Runtime,
        ) config.Field.Runtime {
            if (c.embedded_len != 0) {
                @panic("embedded_len != 0 is not supported for minBitsConfig");
            }

            const actual = self.actualConfig(c);

            // In case of everything fitting in shift, return early
            // to avoid log2_int error.
            if (actual.max_len == 1 and self.len_counts[0] == 0) {
                return actual;
            }

            const item_bits = @bitSizeOf(T);
            var best_embedded_len: usize = actual.max_len;
            var best_max_offset: usize = 0;
            var best_bits = best_embedded_len * item_bits;
            var current_max_offset: usize = 0;

            var i: usize = actual.max_len;
            while (i != 0) {
                i -= 1;
                current_max_offset += (i + 1) * self.len_counts[i];

                const embedded_bits = i * item_bits;

                // We do over-estimate the max offset a bit by taking the
                // offset _after_ the last item, since we don't know what
                // the last item will be. This simplifies creating backing
                // buffers of length `max_offset`.
                const offset_bits = std.math.log2_int(usize, current_max_offset);
                const bits = @max(offset_bits, embedded_bits);

                if (bits < best_bits or (bits == best_bits and current_max_offset <= best_max_offset)) {
                    best_embedded_len = i;
                    best_max_offset = current_max_offset;
                    best_bits = bits;
                }
            }

            inlineAssert(current_max_offset == self.backing.items.len);

            return c.override(.{
                .shift_low = actual.shift_low,
                .shift_high = actual.shift_high,
                .max_len = actual.max_len,
                .max_offset = best_max_offset,
                .embedded_len = best_embedded_len,
            });
        }
    };
}

pub const ShiftTracking = struct {
    shift_low: isize = 0,
    shift_high: isize = 0,

    pub fn deinit(self: *ShiftTracking, allocator: Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn track(self: *ShiftTracking, cp: u21, opt: ?u21) void {
        if (opt) |d| {
            const shift = @as(isize, d) - @as(isize, cp);
            if (self.shift_high < shift) {
                self.shift_high = shift;
            } else if (shift < self.shift_low) {
                self.shift_low = shift;
            }
        }
    }

    pub fn okay(self: *const ShiftTracking, comptime field: config.Field) !bool {
        return basicTrackingOkay(self, field);
    }

    pub fn actualConfig(self: *const ShiftTracking, c: config.Field.Runtime) config.Field.Runtime {
        return c.override(.{
            .shift_low = self.shift_low,
            .shift_high = self.shift_high,
        });
    }

    pub fn minBitsConfig(self: *const ShiftTracking, c: config.Field.Runtime) config.Field.Runtime {
        return self.actualConfig(c);
    }
};

pub const UnionShiftTracking = struct {
    shift: ShiftTracking = .{},

    pub fn deinit(self: *UnionShiftTracking, allocator: Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn track(self: *UnionShiftTracking, cp: u21, value: anytype) void {
        switch (value) {
            inline else => |v| if (@TypeOf(v) == u21) self.shift.track(cp, v),
        }
    }

    pub fn okay(self: *const UnionShiftTracking, comptime field: config.Field) !bool {
        return basicTrackingOkay(self, field);
    }

    pub fn actualConfig(self: *const UnionShiftTracking, c: config.Field.Runtime) config.Field.Runtime {
        return self.shift.actualConfig(c);
    }

    pub fn minBitsConfig(self: *const UnionShiftTracking, c: config.Field.Runtime) config.Field.Runtime {
        return self.shift.minBitsConfig(c);
    }
};

pub fn SliceMap(comptime T: type, comptime V: type) type {
    return std.HashMapUnmanaged([]const T, V, struct {
        pub fn hash(self: @This(), s: []const T) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(718259503);
            std.hash.autoHashStrat(&hasher, s, .Deep);
            const result = hasher.final();
            return result;
        }
        pub fn eql(self: @This(), a: []const T, b: []const T) bool {
            _ = self;
            return std.mem.eql(T, a, b);
        }
    }, std.hash_map.default_max_load_percentage);
}

pub fn PackedOptional(comptime T: type, comptime DataInt: type) type {
    return packed struct {
        data: DataInt,

        const Self = @This();
        pub const Tracking = OptionalTracking(?T);
        const null_data = std.math.maxInt(DataInt);
        pub const @"null" = Self{ .data = null_data };

        pub fn init(opt: ?T) Self {
            if (opt) |value| {
                const d: DataInt = switch (@typeInfo(T)) {
                    .int => value,
                    .@"enum" => @intFromEnum(value),
                    .bool => @intFromBool(value),
                    else => unreachable,
                };
                inlineAssert(d != null_data);
                return .{ .data = d };
            } else {
                return .null;
            }
        }

        pub fn unpack(self: Self) ?T {
            if (self.data == null_data) {
                return null;
            } else {
                return switch (@typeInfo(T)) {
                    .int => @intCast(self.data),
                    .@"enum" => @enumFromInt(self.data),
                    .bool => self.data == 1,
                    else => unreachable,
                };
            }
        }
    };
}

pub fn OptionalTracking(comptime Optional: type) type {
    return struct {
        min_value: isize = 0,
        max_value: isize = 0,

        const Self = @This();
        const T = @typeInfo(Optional).optional.child;

        pub fn deinit(self: *Self, allocator: Allocator) void {
            _ = self;
            _ = allocator;
        }

        pub fn track(self: *Self, opt: ?T) void {
            if (opt) |value| {
                const d: isize = switch (@typeInfo(T)) {
                    .int => value,
                    .@"enum" => @intFromEnum(value),
                    .bool => @intFromBool(value),
                    else => unreachable,
                };
                if (self.max_value < d) {
                    self.max_value = d;
                } else if (d < self.min_value) {
                    self.min_value = d;
                }
            }
        }

        pub fn okay(self: *const Self, comptime field: config.Field) !bool {
            return basicTrackingOkay(self, field);
        }

        pub fn actualConfig(self: *const Self, c: config.Field.Runtime) config.Field.Runtime {
            return c.override(.{
                .min_value = self.min_value,
                .max_value = self.max_value,
            });
        }

        pub fn minBitsConfig(self: *const Self, c: config.Field.Runtime) config.Field.Runtime {
            return self.actualConfig(c);
        }
    };
}

pub fn Shift(
    comptime Int: type,
    comptime is_optional: bool,
    comptime is_packed: bool,
) type {
    // Only valid if `is_optional`
    const null_data = std.math.maxInt(Int);

    return if (is_packed) packed struct {
        data: Int,

        const Self = @This();
        pub const Tracking = ShiftTracking;
        pub const @"null" = Self{ .data = null_data };
        pub const same = Self{ .data = 0 };

        fn _init(cp: u21, d: u21) Self {
            return Self{ .data = @intCast(@as(isize, d) - @as(isize, cp)) };
        }

        fn _initOptional(cp: u21, o: ?u21) Self {
            if (o) |d| {
                return ._init(cp, d);
            } else {
                return .null;
            }
        }

        pub const init = if (is_optional)
            _initOptional
        else
            _init;

        fn _unshift(self: Self, cp: u21) u21 {
            return @intCast(@as(isize, cp) + @as(isize, self.data));
        }

        fn _unshiftOptional(self: Self, cp: u21) ?u21 {
            if (self.data == null_data) {
                return null;
            } else {
                return self._unshift(cp);
            }
        }

        pub const unshift = if (is_optional)
            _unshiftOptional
        else
            _unshift;
    } else struct {
        data: Int,

        const Self = @This();
        pub const Tracking = ShiftTracking;
        pub const @"null" = Self{ .data = null_data };
        pub const same = Self{ .data = 0 };

        fn _init(cp: u21, d: u21) Self {
            return Self{ .data = @intCast(@as(isize, d) - @as(isize, cp)) };
        }

        fn _initOptional(cp: u21, o: ?u21) Self {
            if (o) |d| {
                return ._init(cp, d);
            } else {
                return .null;
            }
        }

        pub const init = if (is_optional)
            _initOptional
        else
            _init;

        fn _unshift(self: Self, cp: u21) u21 {
            return @intCast(@as(isize, cp) + @as(isize, self.data));
        }

        fn _unshiftOptional(self: Self, cp: u21) ?u21 {
            if (self.data == null_data) {
                return null;
            } else {
                return self._unshift(cp);
            }
        }

        pub const unshift = if (is_optional)
            _unshiftOptional
        else
            _unshift;

        pub fn eql(a: Self, b: Self) bool {
            return a.data == b.data;
        }

        pub fn write(self: Self, writer: *std.Io.Writer) !void {
            if (self.eql(.same)) {
                try writer.writeAll(".same");
            } else if ((comptime is_optional) and self.eql(.null)) {
                try writer.writeAll(".null");
            } else {
                try writer.print(
                    \\.{{
                    \\    .data = {},
                    \\}}
                    \\
                , .{self.data});
            }
        }
    };
}

pub fn Union(comptime T: type, comptime _ShiftInt: type, comptime is_packed: bool) type {
    const is_shift = _ShiftInt != void;

    if (!is_packed and !is_shift) {
        return T;
    }

    const info = @typeInfo(T).@"union";
    const Tag = info.tag_type.?;
    const Int = @typeInfo(Tag).@"enum".tag_type;
    inlineAssert(Int == std.meta.Int(.unsigned, @bitSizeOf(Tag)));

    const ShiftMember = if (is_shift)
        Shift(_ShiftInt, false, is_packed)
    else
        void;

    var field_names: [info.fields.len][]const u8 = undefined;
    var field_types: [info.fields.len]type = undefined;
    var field_attrs: [info.fields.len]std.builtin.Type.UnionField.Attributes = undefined;
    for (info.fields, 0..) |f, i| {
        const FieldType = if (is_shift and f.type == u21)
            ShiftMember
        else if (is_packed and is_shift and f.type == void)
            ShiftMember
        else
            f.type;
        field_names[i] = f.name;
        field_types[i] = FieldType;
        field_attrs[i] = .{
            .@"align" = if (is_packed) null else @alignOf(FieldType),
        };
    }

    const InnerUnion = @Union(
        if (is_packed) .@"packed" else .auto,
        if (is_packed) null else Tag,
        &field_names,
        &field_types,
        &field_attrs,
    );

    return if (is_packed) packed struct {
        tag: Int,
        @"union": InnerUnion,

        const Self = @This();

        fn _init(value: T) Self {
            return .{
                .tag = @intFromEnum(@as(Tag, value)),
                .@"union" = switch (value) {
                    inline else => |v, tag| @unionInit(InnerUnion, @tagName(tag), v),
                },
            };
        }

        fn _initShift(cp: u21, value: T) Self {
            return .{
                .tag = @intFromEnum(@as(Tag, value)),
                .@"union" = switch (value) {
                    inline else => |v, tag| if (@FieldType(T, @tagName(tag)) == u21)
                        @unionInit(InnerUnion, @tagName(tag), .init(cp, v))
                    else if (@FieldType(T, @tagName(tag)) == void)
                        @unionInit(InnerUnion, @tagName(tag), .same)
                    else
                        @unionInit(InnerUnion, @tagName(tag), v),
                },
            };
        }

        fn _unpack(self: Self) T {
            const tag: Tag = @enumFromInt(self.tag);
            return switch (tag) {
                inline else => |comptime_tag| @unionInit(
                    T,
                    @tagName(comptime_tag),
                    @field(self.@"union", @tagName(comptime_tag)),
                ),
            };
        }

        fn _unshift(self: Self, cp: u21) T {
            const tag: Tag = @enumFromInt(self.tag);
            return switch (tag) {
                inline else => |comptime_tag| if (@FieldType(T, @tagName(comptime_tag)) == u21)
                    @unionInit(
                        T,
                        @tagName(comptime_tag),
                        @field(self.@"union", @tagName(comptime_tag)).unshift(cp),
                    )
                else if (@FieldType(T, @tagName(comptime_tag)) == void)
                    @unionInit(
                        T,
                        @tagName(comptime_tag),
                        {},
                    )
                else
                    @unionInit(
                        T,
                        @tagName(comptime_tag),
                        @field(self.@"union", @tagName(comptime_tag)),
                    ),
            };
        }

        pub const Tracking = if (is_shift) UnionShiftTracking else void;
        pub const init = if (is_shift) _initShift else _init;
        pub const unpack = if (is_shift) void{} else _unpack;
        pub const unshift = if (is_shift) _unshift else void{};

        pub fn autoHash(self: Self, hasher: anytype) void {
            const tag: Tag = @enumFromInt(self.tag);
            std.hash.autoHash(hasher, tag);
            switch (tag) {
                inline else => |comptime_tag| {
                    std.hash.autoHash(
                        hasher,
                        @field(self.@"union", @tagName(comptime_tag)),
                    );
                },
            }
        }

        pub fn eql(a: Self, b: Self) bool {
            if (a.tag != b.tag) {
                return false;
            }
            const tag: Tag = @enumFromInt(a.tag);
            switch (tag) {
                inline else => |comptime_tag| {
                    const a_v = @field(a.@"union", @tagName(comptime_tag));
                    const b_v = @field(b.@"union", @tagName(comptime_tag));
                    return std.meta.eql(a_v, b_v);
                },
            }
        }
    } else struct {
        @"union": InnerUnion,

        const Self = @This();
        pub const Tracking = UnionShiftTracking;

        pub fn init(cp: u21, value: T) Self {
            return .{
                .@"union" = switch (value) {
                    inline else => |v, tag| if (@FieldType(InnerUnion, @tagName(tag)) == ShiftMember)
                        @unionInit(InnerUnion, @tagName(tag), .init(cp, v))
                    else
                        @unionInit(InnerUnion, @tagName(tag), v),
                },
            };
        }

        pub fn unshift(self: Self, cp: u21) T {
            return switch (self.@"union") {
                inline else => |v, comptime_tag| if (@FieldType(InnerUnion, @tagName(comptime_tag)) == ShiftMember)
                    @unionInit(
                        T,
                        @tagName(comptime_tag),
                        v.unshift(cp),
                    )
                else
                    @unionInit(
                        T,
                        @tagName(comptime_tag),
                        v,
                    ),
            };
        }

        pub fn write(self: Self, writer: *std.Io.Writer) !void {
            try writer.writeAll(
                \\.{
                \\    .@"union" =
            );
            try writer.writeAll(" ");
            try writeField(InnerUnion, writer, self.@"union");
            try writer.writeAll(
                \\,
                \\}
                \\
            );
        }
    };
}

test "packed union with shift and void member" {
    const TestUnion = union(enum) {
        open: u21,
        close: u21,
        none: void,
    };
    const _ShiftInt = ShiftInt(-3, 3, false, true);
    const U = Union(TestUnion, _ShiftInt, true);

    const cp: u21 = 100;

    const open = U.init(cp, .{ .open = 102 });
    try std.testing.expectEqual(TestUnion{ .open = 102 }, open.unshift(cp));

    const close = U.init(cp, .{ .close = 97 });
    try std.testing.expectEqual(TestUnion{ .close = 97 }, close.unshift(cp));

    const none = U.init(cp, .none);
    try std.testing.expectEqual(TestUnion.none, none.unshift(cp));
}
