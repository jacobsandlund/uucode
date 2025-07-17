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

pub const UcdConfig = struct {
    name: OffsetLenConfig = .{},
    decomposition_mapping: OffsetLenConfig = .{},
    numeric_value_numeric: OffsetLenConfig = .{},
    unicode_1_name: OffsetLenConfig = .{},
    case_folding_full: OffsetLenConfig = .{},

    pub fn merge(self: *UcdConfig, other: UcdConfig) UcdConfig {
        inline for (@typeInfo(UcdConfig).@"struct".fields) |field| {
            @field(self, field.name).merge(@field(other, field.name));
        }
    }

    pub fn eql(self: UcdConfig, other: UcdConfig) bool {
        inline for (@typeInfo(UcdConfig).@"struct".fields) |field| {
            if (!@field(self, field.name).eql(@field(other, field.name))) {
                return false;
            }
        }
        return true;
    }
};

const extra_space_when_updating_ucd = 1000;
//const extra_space_when_updating_ucd = 0;

pub const min_config = UcdConfig{
    .name = .{
        .max_len = 88,
        .max_offset = 1031607 + 100 * extra_space_when_updating_ucd,
        .embedded_len = 0,
    },
    .decomposition_mapping = .{
        .max_len = 18,
        .max_offset = 8739 + extra_space_when_updating_ucd,
        .embedded_len = 0,
    },
    .numeric_value_numeric = .{
        .max_len = 13,
        .max_offset = 2302 + extra_space_when_updating_ucd,
        .embedded_len = 0,
    },
    .unicode_1_name = .{
        .max_len = 55,
        .max_offset = 49956 + 5 * extra_space_when_updating_ucd,
        .embedded_len = 0,
    },
    .case_folding_full = .{
        .max_len = 3,
        .max_offset = 224 + extra_space_when_updating_ucd,
        .embedded_len = 0,
    },
};

pub const default_config = UcdConfig{
    .name = .{
        .max_len = 88,
        .max_offset = 1031607,
        .embedded_len = 0,
    },
    .decomposition_mapping = .{
        .max_len = 18,
        .max_offset = 8739,
        .embedded_len = 0,
    },
    .numeric_value_numeric = .{
        .max_len = 13,
        .max_offset = 2302,
        .embedded_len = 0,
    },
    .unicode_1_name = .{
        .max_len = 55,
        .max_offset = 49956,
        .embedded_len = 0,
    },
    .case_folding_full = .{
        .max_len = 3,
        .max_offset = 224,
        .embedded_len = 0,
    },
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

pub const UnicodeData = struct {
    name: OffsetLen(u8, min_config.name),
    general_category: GeneralCategory,
    canonical_combining_class: u8,
    bidi_class: BidiClass,
    decomposition_type: DecompositionType,
    decomposition_mapping: OffsetLen(u21, min_config.decomposition_mapping),
    numeric_type: NumericType,
    numeric_value_decimal: ?u4,
    numeric_value_digit: ?u4,
    numeric_value_numeric: OffsetLen(u8, min_config.numeric_value_numeric),
    bidi_mirrored: bool,
    unicode_1_name: OffsetLen(u8, min_config.unicode_1_name),
    simple_uppercase_mapping: ?u21,
    simple_lowercase_mapping: ?u21,
    simple_titlecase_mapping: ?u21,
};

pub const CaseFolding = struct {
    case_folding_simple: u21,
    case_folding_turkish: ?u21,
    case_folding_full: OffsetLen(u21, min_config.case_folding_full),
};

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

const full_fields = @typeInfo(FullData).@"struct".fields;

pub const full_data_field_names = brk: {
    var fields: [full_fields.len][]const u8 = undefined;
    for (full_fields, 0..) |field, i| {
        fields[i] = field.name;
    }
    break :brk fields;
};

const full_fields_map = std.static_string_map.StaticStringMap(std.builtin.Type.StructField).initComptime(blk: {
    var kvs: [full_fields.len]struct { []const u8, std.builtin.Type.StructField } = undefined;
    for (full_fields, 0..) |full_field, i| {
        kvs[i] = .{ full_field.name, full_field };
    }

    break :blk kvs;
});

pub fn Data(comptime field_names: []const []const u8, comptime config: UcdConfig) type {
    var fields: [field_names.len]std.builtin.Type.StructField = undefined;

    for (field_names, 0..) |field_name, i| {
        const field = full_fields_map.get(field_name) orelse {
            @compileError("Field '" ++ field_name ++ "' not found in FullData");
        };

        const field_type = switch (@typeInfo(field.type)) {
            .pointer => |pointer| OffsetLen(pointer.child, @field(config, field_name)),
            .optional => |optional| PackedOptional(optional.child),
            else => field.type,
        };

        fields[i] = .{
            .name = field.name,
            .type = field_type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = 0, // Required for packed structs
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .@"packed",
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn SelectedDecls(comptime DataType: type, comptime decl_name: []const u8) type {
    const fields = @typeInfo(DataType).@"struct".fields;

    var decl_fields: [fields.len]std.builtin.Type.StructField = undefined;
    var decl_fields_len: usize = 0;

    inline for (fields) |field| {
        switch (@typeInfo(field.type)) {
            .@"struct" => {
                if (@hasDecl(field.type, decl_name)) {
                    const decl_type = @FieldType(field.type, decl_name);
                    decl_fields[decl_fields_len] = .{
                        .name = field.name,
                        .type = decl_type,
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(decl_type),
                    };
                    decl_fields_len += 1;
                }
            },
            else => {},
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = decl_fields[0..decl_fields_len],
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

        pub fn fromSlice(slice: []const T) Self {
            if (comptime len == 0) return .{ .bits = 0 };

            std.debug.assert(slice.len <= len);
            var bits: Bits = 0;
            for (slice, 0..) |item, i| {
                bits |= @as(Bits, item) << item_bits * i;
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

    pub fn merge(self: *OffsetLenConfig, other: OffsetLenConfig) OffsetLenConfig {
        if (other.max_len != 0) {
            self.max_len = other.max_len;
        }
        if (other.max_offset != 0) {
            self.max_offset = other.max_offset;
        }
        if (other.embedded_len != 0) {
            self.embedded_len = other.embedded_len;
        }
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

        pub fn fromSlice(
            allocator: std.mem.Allocator,
            backing: *BackingArrayLen,
            map: *BackingOffsetMap,
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
                std.debug.print("putting in map of size: {d}\n", .{map.size});
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

                return .{
                    .len = len,
                    .data = .{
                        .offset = offset,
                    },
                };
            }
        }

        pub fn fromSliceTracked(
            allocator: std.mem.Allocator,
            backing: *BackingArrayLen,
            map: *BackingOffsetMap,
            len_tracking: *BackingLenTracking,
            slice: []const T,
        ) !Self {
            const offset = backing.len;
            const result = try Self.fromSlice(allocator, backing, map, slice);
            if (backing.len > offset) {
                len_tracking[result.len] += 1;
            }

            return result;
        }

        pub fn toSlice(self: Self, backing: BackingArrayLen, buffer: *EmbeddedArrayLen) []const T {
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
    };
}

pub fn OffsetMap(comptime T: type, comptime Offset: type) type {
    return std.HashMapUnmanaged([]const T, Offset, struct {
        pub fn hash(self: @This(), s: []const T) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(123581298318);
            std.hash.autoHashStrat(&hasher, s, .Deep);
            return hasher.final();
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
