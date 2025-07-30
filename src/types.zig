const std = @import("std");

pub const FullData = struct {
    // UnicodeData fields
    name: []const u8,
    general_category: GeneralCategory,
    canonical_combining_class: u8,
    bidi_class: BidiClass,
    decomposition_type: DecompositionType,
    decomposition_mapping: []const u21,
    numeric_type: NumericType,
    numeric_value_decimal: ?u4,
    numeric_value_digit: ?u4,
    numeric_value_numeric: []const u8,
    is_bidi_mirrored: bool,
    unicode_1_name: []const u8,
    simple_uppercase_mapping: ?u21,
    simple_lowercase_mapping: ?u21,
    simple_titlecase_mapping: ?u21,

    // CaseFolding fields
    case_folding_simple: ?u21,
    case_folding_turkish: ?u21,
    case_folding_full: []const u21,

    // DerivedCoreProperties fields
    is_math: bool,
    is_alphabetic: bool,
    is_lowercase: bool,
    is_uppercase: bool,
    is_cased: bool,
    is_case_ignorable: bool,
    changes_when_lowercased: bool,
    changes_when_uppercased: bool,
    changes_when_titlecased: bool,
    changes_when_casefolded: bool,
    changes_when_casemapped: bool,
    is_id_start: bool,
    is_id_continue: bool,
    is_xid_start: bool,
    is_xid_continue: bool,
    is_default_ignorable_code_point: bool,
    is_grapheme_extend: bool,
    is_grapheme_base: bool,
    is_grapheme_link: bool,
    indic_conjunct_break: IndicConjunctBreak,

    // EastAsianWidth field
    east_asian_width: EastAsianWidth,

    // GraphemeBreak field
    grapheme_break: GraphemeBreak,

    // EmojiData fields
    is_emoji: bool,
    has_emoji_presentation: bool,
    is_emoji_modifier: bool,
    is_emoji_modifier_base: bool,
    is_emoji_component: bool,
    is_extended_pictographic: bool,
};

pub const TableConfig = struct {
    stages: Stages,
    fields: std.BoundedArray(Field, @typeInfo(FullData).@"struct".fields.len),

    pub const Stages = union(enum) {
        // TODO: support two stage tables (and actually support auto)
        auto: void,
        //two: void,
        //three: void,

        len: Len,

        pub const Len = struct {
            stage1: usize,
            stage2: usize,
            data: usize,
        };

        pub fn eql(self: Stages, other: Stages) bool {
            switch (self) {
                .len => |self_len| {
                    switch (other) {
                        .len => |other_len| {
                            return self_len.data == other_len.data and self_len.stage2 == other_len.stage2 and self_len.stage1 == other_len.stage1;
                        },
                        else => return false,
                    }
                },
                else => {
                    const StagesTagType = @typeInfo(Stages).@"union".tag_type.?;
                    return @as(StagesTagType, self) == @as(StagesTagType, other);
                },
            }
        }
    };

    pub const Field = union(enum) {
        basic: Basic,
        offset_len: OffsetLenField,

        pub const Basic = struct {
            name: []const u8,
        };

        pub const OffsetLenField = struct {
            name: []const u8,
            max_len: usize = 0,
            max_offset: usize = 0,
            embedded_len: usize = 0,
        };

        pub fn name(self: Field) []const u8 {
            return switch (self) {
                .basic => |b| b.name,
                .offset_len => |o| o.name,
            };
        }

        pub fn override(self: Field, other: anytype) Field {
            std.debug.assert(std.mem.eql(u8, self.name(), other.name));

            switch (self) {
                .basic => return self,
                .offset_len => |o| {
                    var result = o;

                    inline for (@typeInfo(@TypeOf(other)).@"struct".fields) |field| {
                        @field(result, field.name) = @field(other, field.name);
                    }

                    return .{ .offset_len = result };
                },
            }
        }

        pub fn eql(self: Field, other: Field) bool {
            const FieldEnum = @typeInfo(Field).@"union".tag_type.?;

            if (@as(FieldEnum, self) != @as(FieldEnum, other)) return false;

            switch (self) {
                .basic => |a| {
                    const b = other.basic;
                    return std.mem.eql(u8, a.name, b.name);
                },
                .offset_len => |a| {
                    const b = other.offset_len;
                    return a.max_len == b.max_len and
                        a.max_offset == b.max_offset and
                        a.embedded_len == b.embedded_len and
                        std.mem.eql(u8, a.name, b.name);
                },
            }
        }
    };

    pub fn hasField(self: *const TableConfig, name: []const u8) bool {
        return for (self.fields.slice()) |field| {
            if (std.mem.eql(u8, field.name(), name)) {
                break true;
            }
        } else false;
    }

    pub fn getField(self: *const TableConfig, name: []const u8) ?Field {
        return for (self.fields.slice()) |field| {
            if (std.mem.eql(u8, field.name(), name)) {
                break field;
            }
        } else null;
    }

    pub fn override(self: *const TableConfig, other: anytype) TableConfig {
        var result = self.*;

        if (!@hasField(@TypeOf(other), "fields")) {
            @compileError("Table config must define `fields`");
        }
        //switch (@typeInfo(@FieldType(@TypeOf(other), "fields"))) {
        //    .pointer => |pointer|
        //}

        result.fields.clear();
        inline for (other.fields) |field| {
            switch (@typeInfo(@TypeOf(field))) {
                .@"struct" => {
                    const original = self.getField(field.name) orelse {
                        std.debug.panic("Field '{s}' not found in TableConfig being overriden", .{field.name});
                    };
                    result.fields.appendAssumeCapacity(original.override(field));
                },
                .pointer, .array => {
                    if (self.getField(field)) |original| {
                        result.fields.appendAssumeCapacity(original);
                    } else {
                        result.fields.appendAssumeCapacity(.{ .basic = .{
                            .name = field,
                        } });
                    }
                },
                else => @compileError("Field has unexpected type"),
            }
        }

        if (@hasField(@TypeOf(other), "stages")) {
            switch (@typeInfo(@FieldType(@TypeOf(other), "stages"))) {
                .@"struct" => |struct_info| {
                    if (struct_info.fields.len != 1 or !std.mem.eql(u8, struct_info.fields[0].name, "len")) {
                        @compileError("Stages struct must have a single field named `len`");
                    }
                    result.stages = .{ .len = .{
                        .stage1 = other.stages.len.stage1,
                        .stage2 = other.stages.len.stage2,
                        .data = other.stages.len.data,
                    } };
                },
                .@"enum" => {
                    result.stages = other.stages;
                },
                else => {
                    @compileError("Unknown stages type " ++ @typeName(@FieldType(@TypeOf(other), "stages")));
                },
            }
        }

        return result;
    }

    pub fn eql(self: *const TableConfig, other: *const TableConfig) bool {
        if (self.fields.len != other.fields.len or !self.stages.eql(other.stages)) {
            return false;
        }

        for (self.fields.slice(), other.fields.slice()) |a, b| {
            if (!a.eql(b)) {
                return false;
            }
        }

        return true;
    }
};

pub const GeneralCategory = enum(u5) {
    Lu, // Letter, uppercase
    Ll, // Letter, lowercase
    Lt, // Letter, titlecase
    Lm, // Letter, modifier
    Lo, // Letter, other
    Mn, // Mark, nonspacing
    Mc, // Mark, spacing combining
    Me, // Mark, enclosing
    Nd, // Number, decimal digit
    Nl, // Number, letter
    No, // Number, other
    Pc, // Punctuation, connector
    Pd, // Punctuation, dash
    Ps, // Punctuation, open
    Pe, // Punctuation, close
    Pi, // Punctuation, initial quote
    Pf, // Punctuation, final quote
    Po, // Punctuation, other
    Sm, // Symbol, math
    Sc, // Symbol, currency
    Sk, // Symbol, modifier
    So, // Symbol, other
    Zs, // Separator, space
    Zl, // Separator, line
    Zp, // Separator, paragraph
    Cc, // Other, control
    Cf, // Other, format
    Cs, // Other, surrogate
    Co, // Other, private use
    Cn, // Other, not assigned
};

pub const BidiClass = enum(u5) {
    L, // Left-to-Right
    LRE, // Left-to-Right Embedding
    LRO, // Left-to-Right Override
    R, // Right-to-Left
    AL, // Right-to-Left Arabic
    RLE, // Right-to-Left Embedding
    RLO, // Right-to-Left Override
    PDF, // Pop Directional Format
    EN, // European Number
    ES, // European Number Separator
    ET, // European Number Terminator
    AN, // Arabic Number
    CS, // Common Number Separator
    NSM, // Nonspacing Mark
    BN, // Boundary Neutral
    B, // Paragraph Separator
    S, // Segment Separator
    WS, // Whitespace
    ON, // Other Neutrals
    LRI, // Left-to-Right Isolate
    RLI, // Right-to-Left Isolate
    FSI, // First Strong Isolate
    PDI, // Pop Directional Isolate
};

pub const DecompositionType = enum(u5) {
    default,
    canonical,
    font,
    noBreak,
    initial,
    medial,
    final,
    isolated,
    circle,
    super,
    sub,
    vertical,
    wide,
    narrow,
    small,
    square,
    fraction,
    compat,
};

pub const NumericType = enum(u2) {
    none,
    decimal,
    digit,
    numeric,
};

pub fn UnicodeData(comptime config: TableConfig) type {
    return struct {
        name: OffsetLen(u8, config.getField("name").?.offset_len),
        general_category: GeneralCategory,
        canonical_combining_class: u8,
        bidi_class: BidiClass,
        decomposition_type: DecompositionType,
        decomposition_mapping: OffsetLen(u21, config.getField("decomposition_mapping").?.offset_len),
        numeric_type: NumericType,
        numeric_value_decimal: PackedOptional(u4),
        numeric_value_digit: PackedOptional(u4),
        numeric_value_numeric: OffsetLen(u8, config.getField("numeric_value_numeric").?.offset_len),
        is_bidi_mirrored: bool,
        unicode_1_name: OffsetLen(u8, config.getField("unicode_1_name").?.offset_len),
        simple_uppercase_mapping: PackedOptional(u21),
        simple_lowercase_mapping: PackedOptional(u21),
        simple_titlecase_mapping: PackedOptional(u21),
    };
}

pub fn CaseFolding(comptime config: TableConfig) type {
    return struct {
        case_folding_simple: PackedOptional(u21),
        case_folding_turkish: PackedOptional(u21),
        case_folding_full: OffsetLen(u21, config.getField("case_folding_full").?.offset_len),
    };
}

pub const IndicConjunctBreak = enum(u2) {
    none,
    linker,
    consonant,
    extend,
};

pub const DerivedCoreProperties = struct {
    is_math: bool = false,
    is_alphabetic: bool = false,
    is_lowercase: bool = false,
    is_uppercase: bool = false,
    is_cased: bool = false,
    is_case_ignorable: bool = false,
    changes_when_lowercased: bool = false,
    changes_when_uppercased: bool = false,
    changes_when_titlecased: bool = false,
    changes_when_casefolded: bool = false,
    changes_when_casemapped: bool = false,
    is_id_start: bool = false,
    is_id_continue: bool = false,
    is_xid_start: bool = false,
    is_xid_continue: bool = false,
    is_default_ignorable_code_point: bool = false,
    is_grapheme_extend: bool = false,
    is_grapheme_base: bool = false,
    is_grapheme_link: bool = false,
    indic_conjunct_break: IndicConjunctBreak = .none,
};

pub const EastAsianWidth = enum(u3) {
    neutral,
    fullwidth,
    halfwidth,
    wide,
    narrow,
    ambiguous,
};

pub const GraphemeBreak = enum(u4) {
    other,
    prepend,
    cr,
    lf,
    control,
    extend,
    regional_indicator,
    spacingmark,
    l,
    v,
    t,
    lv,
    lvt,
    zwj,
};

pub const EmojiData = packed struct {
    is_emoji: bool = false,
    has_emoji_presentation: bool = false,
    is_emoji_modifier: bool = false,
    is_emoji_modifier_base: bool = false,
    is_emoji_component: bool = false,
    is_extended_pictographic: bool = false,
};

pub fn Table(comptime config: TableConfig) type {
    @setEvalBranchQuota(10_000);
    const full_fields_map = comptime std.static_string_map.StaticStringMap(std.builtin.Type.StructField).initComptime(blk: {
        const full_fields = @typeInfo(FullData).@"struct".fields;
        var kvs: [full_fields.len]struct { []const u8, std.builtin.Type.StructField } = undefined;
        for (full_fields, 0..) |full_field, i| {
            kvs[i] = .{ full_field.name, full_field };
        }

        break :blk kvs;
    });

    var data_fields: [config.fields.len + 1]std.builtin.Type.StructField = undefined;
    var data_bit_size: usize = 0;
    var backing_arrays: [config.fields.len]std.builtin.Type.StructField = undefined;
    var backing_len: usize = 0;

    for (config.fields.slice(), 0..) |field_config, i| {
        const field = full_fields_map.get(field_config.name()) orelse {
            @compileError("Field '" ++ field_config.name() ++ "' not found in FullData");
        };

        const field_type = switch (@typeInfo(field.type)) {
            .pointer => |pointer| blk: {
                const OL = OffsetLen(pointer.child, field_config.offset_len);

                backing_arrays[backing_len] = .{
                    .name = field.name,
                    .type = OL.BackingArrayLen,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(OL.BackingArrayLen),
                };
                backing_len += 1;

                break :blk OL;
            },
            .optional => |optional| PackedOptional(optional.child),
            else => field.type,
        };

        data_fields[i] = .{
            .name = field.name,
            .type = field_type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = 0, // Required for packed structs
        };
        data_bit_size += @bitSizeOf(field_type);
    }

    const bits_over_byte = data_bit_size % 8;
    const padding_bits = if (bits_over_byte == 0) 0 else 8 - bits_over_byte;
    data_bit_size += padding_bits;

    data_fields[config.fields.len] = .{
        .name = "_padding",
        .type = std.meta.Int(.unsigned, padding_bits),
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = 0, // Required for packed structs
    };

    const Data = @Type(.{
        .@"struct" = .{
            .layout = .@"packed",
            .backing_integer = std.meta.Int(.unsigned, data_bit_size),
            .fields = &data_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });

    const len: TableConfig.Stages.Len = switch (config.stages) {
        .len => |len| len,
        else => .{ .stage1 = 0, .stage2 = 0, .data = 0 },
    };

    const DataArray = @Type(.{
        .array = .{
            .len = len.data,
            .child = Data,
            .sentinel_ptr = null,
        },
    });

    const BackingArrays = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = backing_arrays[0..backing_len],
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });

    var table_fields: [4]std.builtin.Type.StructField = .{
        .{
            .name = "backing",
            .type = BackingArrays,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(BackingArrays),
        },
        .{
            .name = "data",
            .type = DataArray,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(Data),
        },
        undefined,
        undefined,
    };
    var table_fields_len: usize = 2;

    if (len.stage2 > 0) {
        const DataOffset = std.math.IntFittingRange(0, len.data);

        const Stage2 = @Type(.{
            .array = .{
                .len = len.stage2,
                .child = DataOffset,
                .sentinel_ptr = null,
            },
        });

        table_fields[table_fields_len] = .{
            .name = "stage2",
            .type = Stage2,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(DataOffset),
        };
        table_fields_len += 1;
    }

    if (len.stage1 > 0) {
        const next_stage_len = if (len.stage2 > 0) len.stage2 else len.data;
        const block_size = 256;
        const blocks_len = try std.math.divCeil(usize, next_stage_len, block_size);
        const BlockOffset = std.math.IntFittingRange(0, blocks_len);

        const Stage1 = @Type(.{
            .array = .{
                .len = len.stage1,
                .child = BlockOffset,
                .sentinel_ptr = null,
            },
        });

        table_fields[table_fields_len] = .{
            .name = "stage1",
            .type = Stage1,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(BlockOffset),
        };
        table_fields_len += 1;
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = table_fields[0..table_fields_len],
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn ArrayLen(comptime T: type, comptime max_len: comptime_int) type {
    return struct {
        items: [max_len]T,
        len: Len,

        const Len = std.math.IntFittingRange(0, max_len);

        pub fn appendAssumeCapacity(self: *@This(), item: T) void {
            self.items[self.len] = item;
            self.len += 1;
        }

        pub fn appendSliceAssumeCapacity(self: *@This(), slice: []const T) void {
            @memcpy(self.items[self.len..][0..slice.len], slice);
            self.len += @intCast(slice.len);
        }

        pub fn toSlice(self: @This()) []const T {
            return self.items[0..self.len];
        }
    };
}

pub fn PackedArray(comptime T: type, comptime capacity: comptime_int) type {
    return packed struct {
        bits: Bits,

        const Self = @This();
        const item_bits = @bitSizeOf(T);
        const Bits = std.meta.Int(.unsigned, item_bits * capacity);
        const ShiftBits = std.math.Log2Int(Bits);

        pub fn fromSlice(slice: []const T) Self {
            if ((comptime capacity == 0) or slice.len == 0) return .{ .bits = 0 };

            // This may make 1 length slices slightly faster, but it's
            // primarily avoiding an issue where `item_bits` is actually too
            // big to be a valid shift value, and zig can't tell that `i` would
            // never be anything other than 0.
            if (comptime capacity == 1) return .{ .bits = @as(Bits, slice[0]) };

            std.debug.assert(slice.len <= capacity);
            var bits: Bits = 0;
            for (slice, 0..) |item, i| {
                bits |= @as(Bits, item) << item_bits * @as(ShiftBits, @intCast(i));
            }
            return .{ .bits = bits };
        }

        pub fn toSlice(self: Self, buffer: []T, len: usize) []T {
            inline for (0..capacity) |i| {
                buffer[i] = @as(T, @truncate(self.bits >> item_bits * i));
            }
            return buffer[0..len];
        }
    };
}

pub fn OffsetLen(
    comptime T: type,
    comptime config: TableConfig.Field.OffsetLenField,
) type {
    const name = config.name;
    const max_len = config.max_len;
    const max_offset = config.max_offset;
    const embedded_len = config.embedded_len;

    if (max_len == 0) {
        @compileError("OffsetLen with max_len == 0 is not supported due to Zig compiler bug");
    }

    return packed struct {
        data: packed union {
            embedded: EmbeddedArray,
            offset: Offset,
        },
        len: Len,

        const Self = @This();
        const EmbeddedArray = PackedArray(T, embedded_len);
        pub const Offset = std.math.IntFittingRange(0, max_offset);
        const Len = std.math.IntFittingRange(0, max_len);

        pub const empty = Self{ .len = 0, .data = .{ .offset = 0 } };

        pub const BackingArrayLen = ArrayLen(T, max_offset);
        pub const BackingOffsetMap = OffsetMap(T, Offset);
        pub const BackingLenTracking: type = [max_len]Offset;

        pub fn fromSliceTracked(
            allocator: std.mem.Allocator,
            backing: *BackingArrayLen,
            map: *BackingOffsetMap,
            len_tracking: *BackingLenTracking,
            slice: []const T,
        ) !Self {
            const len: Len = @intCast(slice.len);

            if (comptime embedded_len == 0 and max_offset == 0) {
                return .empty;
            } else if ((comptime embedded_len == max_len) or slice.len <= embedded_len) {
                return .{
                    .len = len,
                    .data = .{
                        .embedded = EmbeddedArray.fromSlice(slice),
                    },
                };
            } else {
                const gop = try map.getOrPut(allocator, slice);
                if (gop.found_existing) {
                    return .{
                        .len = len,
                        .data = .{
                            .offset = gop.value_ptr.*,
                        },
                    };
                }

                const offset = backing.len;
                gop.value_ptr.* = offset;
                backing.appendSliceAssumeCapacity(slice);
                gop.key_ptr.* = backing.items[offset .. offset + slice.len];
                len_tracking[slice.len - 1] += 1;

                return .{
                    .len = len,
                    .data = .{
                        .offset = offset,
                    },
                };
            }
        }

        pub fn toSlice(
            self: *const Self,
            backing: *const BackingArrayLen,
            buffer: []T,
        ) []const T {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            if (comptime embedded_len == max_len) {
                return self.data.embedded.toSlice(buffer, self.len);
            } else if (comptime embedded_len == 0) {
                return backing.items[self.data.offset .. self.data.offset + self.len];
            } else if (self.len <= embedded_len) {
                return self.data.embedded.toSlice(buffer, self.len);
            } else {
                return backing.items[self.data.offset .. self.data.offset + self.len];
            }
        }

        pub fn autoHash(self: Self, hasher: anytype) void {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            std.hash.autoHash(hasher, self.len);
            if (comptime embedded_len == max_len) {
                return std.hash.autoHash(hasher, self.data.embedded);
            } else if (comptime embedded_len == 0) {
                return std.hash.autoHash(hasher, self.data.offset);
            } else if (self.len <= embedded_len) {
                return std.hash.autoHash(hasher, self.data.embedded);
            } else {
                return std.hash.autoHash(hasher, self.data.offset);
            }
        }

        pub fn tightConfig(
            backing: *BackingArrayLen,
        ) TableConfig.Field.OffsetLenField {
            return .{
                .name = name,
                .max_len = max_len,
                .max_offset = backing.len,
                .embedded_len = embedded_len,
            };
        }

        pub fn minBitsConfig(
            backing: *BackingArrayLen,
            len_tracking: *BackingLenTracking,
        ) TableConfig.Field.OffsetLenField {
            if (comptime embedded_len != 0) {
                @compileError("embedded_len != 0 is not supported for minBitsConfig");
            }

            var i = max_len;
            while (i != 0) {
                i -= 1;
                if (len_tracking[i] != 0) {
                    break;
                }
            } else return .{
                .name = name,
                .max_len = 0,
                .max_offset = 0,
                .embedded_len = 0,
            };

            const actual_max_len = i + 1;
            const item_bits = @bitSizeOf(T);
            var best_embedded_len: usize = actual_max_len;
            var best_max_offset: usize = 0;
            var best_bits = best_embedded_len * item_bits;
            var current_max_offset: usize = 0;

            i += 1;
            while (i != 0) {
                i -= 1;
                current_max_offset += (i + 1) * len_tracking[i];

                const embedded_bits = i * item_bits;

                // We do over-estimate the max offset a bit by taking the
                // offset _after_ the last item, since we don't know what the
                // last item will be. This simplifies creating backing arrays
                // of length `max_offset`.
                const offset_bits = std.math.log2_int(usize, current_max_offset);
                const bits = @max(offset_bits, embedded_bits);

                if (bits < best_bits or (bits == best_bits and current_max_offset <= best_max_offset)) {
                    best_embedded_len = i;
                    best_max_offset = current_max_offset;
                    best_bits = bits;
                }
            }

            std.debug.assert(current_max_offset == backing.len);

            return .{
                .name = name,
                .max_len = actual_max_len,
                .max_offset = best_max_offset,
                .embedded_len = best_embedded_len,
            };
        }
    };
}

pub fn OffsetMap(comptime T: type, comptime Offset: type) type {
    return std.HashMapUnmanaged([]const T, Offset, struct {
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

// Note: this can only be used for types where the max value isn't a valid
// value, which is the case for all optional types in FullData.
pub fn PackedOptional(comptime T: type) type {
    const max = std.math.maxInt(T);

    return packed struct {
        data: T,

        const Self = @This();

        pub const @"null" = Self{ .data = max };

        pub fn fromOptional(optional: ?T) Self {
            if (optional) |value| {
                std.debug.assert(value != max);
                return .{ .data = value };
            } else {
                return .null;
            }
        }

        pub fn toOptional(self: Self) ?T {
            if (self.data != max) {
                return self.data;
            } else {
                return null;
            }
        }
    };
}
