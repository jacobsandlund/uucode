const std = @import("std");

pub const min_code_point: u21 = 0x0000;
pub const max_code_point: u21 = 0x10FFFF;
pub const num_code_points: u21 = max_code_point + 1;
pub const code_point_range_end: u21 = max_code_point + 1;

const safe_max_offset = std.math.maxInt(u24);

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
    bidi_mirrored: bool,
    unicode_1_name: []const u8,
    simple_uppercase_mapping: ?u21,
    simple_lowercase_mapping: ?u21,
    simple_titlecase_mapping: ?u21,

    // CaseFolding fields
    case_folding_simple: ?u21,
    case_folding_turkish: ?u21,
    case_folding_full: []const u21,

    // DerivedCoreProperties fields
    math: bool,
    alphabetic: bool,
    lowercase: bool,
    uppercase: bool,
    cased: bool,
    case_ignorable: bool,
    changes_when_lowercased: bool,
    changes_when_uppercased: bool,
    changes_when_titlecased: bool,
    changes_when_casefolded: bool,
    changes_when_casemapped: bool,
    id_start: bool,
    id_continue: bool,
    xid_start: bool,
    xid_continue: bool,
    default_ignorable_code_point: bool,
    grapheme_extend: bool,
    grapheme_base: bool,
    grapheme_link: bool,
    indic_conjunct_break: IndicConjunctBreak,

    // EastAsianWidth field
    east_asian_width: EastAsianWidth,

    // GraphemeBreak field
    grapheme_break: GraphemeBreak,

    // EmojiData fields
    emoji: bool,
    emoji_presentation: bool,
    emoji_modifier: bool,
    emoji_modifier_base: bool,
    emoji_component: bool,
    extended_pictographic: bool,
};

pub const TableConfig = struct {
    fields: []const []const u8,
    data_len: usize,
    name: OffsetLenConfig,
    decomposition_mapping: OffsetLenConfig,
    numeric_value_numeric: OffsetLenConfig,
    unicode_1_name: OffsetLenConfig,
    case_folding_full: OffsetLenConfig,

    pub const offset_len_fields = .{ "name", "decomposition_mapping", "numeric_value_numeric", "unicode_1_name", "case_folding_full" };

    pub fn override(self: *const TableConfig, other: anytype) TableConfig {
        var result = self.*;
        if (@hasField(@TypeOf(other), "fields")) {
            result.fields = other.fields;
        }
        if (@hasField(@TypeOf(other), "data_len")) {
            result.data_len = other.data_len;
        }
        inline for (offset_len_fields) |field| {
            if (@hasField(@TypeOf(other), field)) {
                @field(result, field) = @field(self, field).override(@field(other, field));
            }
        }

        return result;
    }

    pub fn eql(self: *const TableConfig, other: *const TableConfig) bool {
        if (self.data_len != other.data_len or self.fields.len != other.fields.len) {
            return false;
        }

        for (self.fields, other.fields) |a, b| {
            if (!std.mem.eql(u8, a, b)) {
                return false;
            }
        }

        inline for (offset_len_fields) |field| {
            if (!@field(self, field).eql(@field(other, field))) {
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
        name: OffsetLen(u8, config.name),
        general_category: GeneralCategory,
        canonical_combining_class: u8,
        bidi_class: BidiClass,
        decomposition_type: DecompositionType,
        decomposition_mapping: OffsetLen(u21, config.decomposition_mapping),
        numeric_type: NumericType,
        numeric_value_decimal: PackedOptional(u4),
        numeric_value_digit: PackedOptional(u4),
        numeric_value_numeric: OffsetLen(u8, config.numeric_value_numeric),
        bidi_mirrored: bool,
        unicode_1_name: OffsetLen(u8, config.unicode_1_name),
        simple_uppercase_mapping: PackedOptional(u21),
        simple_lowercase_mapping: PackedOptional(u21),
        simple_titlecase_mapping: PackedOptional(u21),
    };
}

pub fn CaseFolding(comptime config: TableConfig) type {
    return struct {
        case_folding_simple: PackedOptional(u21),
        case_folding_turkish: PackedOptional(u21),
        case_folding_full: OffsetLen(u21, config.case_folding_full),
    };
}

pub const IndicConjunctBreak = enum(u2) {
    none,
    linker,
    consonant,
    extend,
};

pub const DerivedCoreProperties = struct {
    math: bool = false,
    alphabetic: bool = false,
    lowercase: bool = false,
    uppercase: bool = false,
    cased: bool = false,
    case_ignorable: bool = false,
    changes_when_lowercased: bool = false,
    changes_when_uppercased: bool = false,
    changes_when_titlecased: bool = false,
    changes_when_casefolded: bool = false,
    changes_when_casemapped: bool = false,
    id_start: bool = false,
    id_continue: bool = false,
    xid_start: bool = false,
    xid_continue: bool = false,
    default_ignorable_code_point: bool = false,
    grapheme_extend: bool = false,
    grapheme_base: bool = false,
    grapheme_link: bool = false,
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
    emoji: bool = false,
    emoji_presentation: bool = false,
    emoji_modifier: bool = false,
    emoji_modifier_base: bool = false,
    emoji_component: bool = false,
    extended_pictographic: bool = false,
};

pub fn TableData(comptime config: TableConfig) type {
    const full_fields_map = comptime std.static_string_map.StaticStringMap(std.builtin.Type.StructField).initComptime(blk: {
        const full_fields = @typeInfo(FullData).@"struct".fields;
        var kvs: [full_fields.len]struct { []const u8, std.builtin.Type.StructField } = undefined;
        for (full_fields, 0..) |full_field, i| {
            kvs[i] = .{ full_field.name, full_field };
        }

        break :blk kvs;
    });

    var data_fields: [config.fields.len]std.builtin.Type.StructField = undefined;
    var backing_arrays: [config.fields.len]std.builtin.Type.StructField = undefined;
    var backing_len: usize = 0;

    for (config.fields, 0..) |field_name, i| {
        const field = full_fields_map.get(field_name) orelse {
            @compileError("Field '" ++ field_name ++ "' not found in FullData");
        };

        const field_type = switch (@typeInfo(field.type)) {
            .pointer => |pointer| blk: {
                const OL = OffsetLen(pointer.child, @field(config, field_name));

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
    }

    const Data = @Type(.{
        .@"struct" = .{
            .layout = .@"packed",
            .fields = &data_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });

    const DataArray = @Type(.{
        .array = .{
            .len = config.data_len,
            .child = Data,
            .sentinel_ptr = null,
        },
    });

    const Offset = std.math.IntFittingRange(0, config.data_len);
    const Offsets = @Type(.{
        .array = .{
            .len = code_point_range_end,
            .child = Offset,
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

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &.{
                .{
                    .name = "data",
                    .type = DataArray,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(Data),
                },
                .{
                    .name = "offsets",
                    .type = Offsets,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(Offsets),
                },
                .{
                    .name = "backing",
                    .type = BackingArrays,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(BackingArrays),
                },
            },
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn ArrayLen(comptime T: type, comptime max_len_: comptime_int) type {
    return struct {
        items: [max_len]T,
        len: Len,

        pub const Len = std.math.IntFittingRange(0, max_len);
        pub const max_len = max_len_;

        fn appendSliceAssumeCapacity(self: *@This(), slice: []const T) void {
            @memcpy(self.items[self.len..][0..slice.len], slice);
            self.len += @intCast(slice.len);
        }

        fn toSlice(self: @This()) []T {
            return self.items[0..self.len];
        }
    };
}

pub fn PackedArray(comptime T: type, comptime len: comptime_int) type {
    const item_bits = @bitSizeOf(T);

    return packed struct {
        const Self = @This();

        bits: Bits,

        pub const Bits = std.meta.Int(.unsigned, item_bits * len);
        pub const Array = ArrayLen(T, len);
        const ShiftBits = std.math.Log2Int(Bits);

        pub fn fromSlice(slice: []const T) Self {
            if ((comptime len == 0) or slice.len == 0) return .{ .bits = 0 };

            // This may make 1 length slices slightly faster, but it's
            // primarily avoiding an issue where `item_bits` is actually too
            // big to be a valid shift value, and zig can't tell that `i` would
            // never be anything other than 0.
            if (comptime len == 1) return .{ .bits = @as(Bits, slice[0]) };

            std.debug.assert(slice.len <= len);
            var bits: Bits = 0;
            for (slice, 0..) |item, i| {
                bits |= @as(Bits, item) << item_bits * @as(ShiftBits, @intCast(i));
            }
            return .{ .bits = bits };
        }

        pub fn toArray(self: Self, array: *Array) void {
            inline for (0..len) |i| {
                array[i] = @as(T, @truncate(self.bits >> item_bits * i));
            }
        }
    };
}

pub const OffsetLenConfig = struct {
    max_len: usize = 0,
    max_offset: usize = 0,
    embedded_len: usize = 0,

    pub fn override(self: OffsetLenConfig, other: anytype) OffsetLenConfig {
        var result = self;
        inline for (@typeInfo(@TypeOf(other)).@"struct".fields) |field| {
            @field(result, field.name) = @field(other, field.name);
        }

        return result;
    }

    pub fn eql(self: OffsetLenConfig, other: OffsetLenConfig) bool {
        return self.max_len == other.max_len and
            self.max_offset == other.max_offset and
            self.embedded_len == other.embedded_len;
    }
};

pub fn OffsetLen(
    comptime T: type,
    comptime config: OffsetLenConfig,
) type {
    if (config.max_len == 0) {
        @compileError("OffsetLen with max_len == 0 is not supported due to Zig compiler bug");
    }

    return packed struct {
        data: packed union {
            embedded: EmbeddedArray,
            offset: Offset,
        },
        len: Len,

        const Self = @This();

        pub const empty = Self{ .len = 0, .data = .{ .offset = 0 } };

        pub const Offset = std.math.IntFittingRange(0, config.max_offset);
        pub const Len = std.math.IntFittingRange(0, config.max_len);
        pub const EmbeddedArray = PackedArray(T, config.embedded_len);

        pub const max_len = config.max_len;
        pub const max_offset = config.max_offset;
        pub const embedded_len = config.embedded_len;

        pub const EmbeddedArrayLen = ArrayLen(T, embedded_len);
        pub const BackingArrayLen = ArrayLen(T, max_offset);
        pub const BackingOffsetMap = OffsetMap(T, Offset);
        pub const BackingLenTracking: type = [config.max_len]Offset;

        pub fn fromSliceTracked(
            allocator: std.mem.Allocator,
            backing: *BackingArrayLen,
            map: *BackingOffsetMap,
            len_tracking: *BackingLenTracking,
            slice: []const T,
        ) !Self {
            const len: Len = @intCast(slice.len);

            if ((comptime embedded_len == max_len) or slice.len <= embedded_len) {
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
            buffer: *EmbeddedArrayLen,
        ) []const T {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            if (comptime embedded_len == max_len) {
                return self.data.embedded.toArray(buffer)[0..self.len];
            } else if (comptime embedded_len == 0) {
                return backing.items[self.data.offset .. self.data.offset + self.len];
            } else if (self.len <= embedded_len) {
                return self.data.embedded.toArray(buffer)[0..self.len];
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
        ) OffsetLenConfig {
            return .{
                .max_len = max_len,
                .max_offset = backing.len,
                .embedded_len = embedded_len,
            };
        }

        pub fn minBitsConfig(
            backing: *BackingArrayLen,
            len_tracking: *BackingLenTracking,
        ) OffsetLenConfig {
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
