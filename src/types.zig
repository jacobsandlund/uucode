const std = @import("std");

pub const min_code_point: u21 = 0x0000;
pub const max_code_point: u21 = 0x10FFFF;
pub const num_code_points: u21 = max_code_point + 1;
pub const code_point_range_end: u21 = max_code_point + 1;

const safe_max_offset = std.math.maxInt(u24);

pub fn FullData(comptime cfg: UcdConfig) type {
    return struct {
        // UnicodeData fields
        name: OffsetLen(u8, cfg.name_max_len, cfg.name_max_offset, cfg.name_embedded_len),
        general_category: GeneralCategory,
        canonical_combining_class: u8,
        bidi_class: BidiClass,
        decomposition_type: DecompositionType,
        decomposition_mapping: OffsetLen(u21, cfg.decomposition_mapping_max_len, cfg.decomposition_mapping_max_offset, cfg.decomposition_mapping_embedded_len),
        numeric_type: NumericType,
        numeric_value_decimal: ?u4,
        numeric_value_digit: ?u4,
        numeric_value_numeric: OffsetLen(u8, cfg.numeric_value_numeric_max_len, cfg.numeric_value_numeric_max_offset, cfg.numeric_value_numeric_embedded_len),
        bidi_mirrored: bool,
        unicode_1_name: OffsetLen(u8, cfg.unicode_1_name_max_len, cfg.unicode_1_name_max_offset, cfg.unicode_1_name_embedded_len),
        iso_comment: OffsetLen(u8, cfg.iso_comment_max_len, cfg.iso_comment_max_offset, cfg.iso_comment_embedded_len),
        simple_uppercase_mapping: ?u21,
        simple_lowercase_mapping: ?u21,
        simple_titlecase_mapping: ?u21,

        // CaseFolding fields
        case_folding_simple: u21 = 0,
        case_folding_turkish: ?u21 = null,
        case_folding_full: OffsetLen(u21, cfg.case_folding_full_max_len, cfg.case_folding_full_max_offset, cfg.case_folding_full_embedded_len),

        // DerivedCoreProperties fields
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

        // EastAsianWidth field
        east_asian_width: EastAsianWidth,

        // GraphemeBreak field
        grapheme_break: GraphemeBreak,

        // EmojiData fields
        emoji: bool = false,
        emoji_presentation: bool = false,
        emoji_modifier: bool = false,
        emoji_modifier_base: bool = false,
        emoji_component: bool = false,
        extended_pictographic: bool = false,
    };
}

pub const UcdConfig = struct {
    name_max_len: usize = 0,
    name_max_offset: usize = 0,
    name_embedded_len: usize = 0,
    decomposition_mapping_max_len: usize = 0,
    decomposition_mapping_max_offset: usize = 0,
    decomposition_mapping_embedded_len: usize = 0,
    numeric_value_numeric_max_len: usize = 0,
    numeric_value_numeric_max_offset: usize = 0,
    numeric_value_numeric_embedded_len: usize = 0,
    unicode_1_name_max_len: usize = 0,
    unicode_1_name_max_offset: usize = 0,
    unicode_1_name_embedded_len: usize = 0,
    iso_comment_max_len: usize = 0,
    iso_comment_max_offset: usize = 0,
    iso_comment_embedded_len: usize = 0,
    case_folding_full_max_len: usize = 0,
    case_folding_full_max_offset: usize = 0,
    case_folding_full_embedded_len: usize = 0,
};

pub fn Data(comptime field_names: []const []const u8, comptime cfg: UcdConfig) type {
    const full_data_info = @typeInfo(FullData(cfg));
    const full_fields = full_data_info.@"struct".fields;

    const full_fields_kvs: [full_fields.len]struct { []const u8, std.builtin.Type.StructField } = blk: {
        var kvs: [full_fields.len]struct { []const u8, std.builtin.Type.StructField } = undefined;
        for (full_fields, 0..) |full_field, i| {
            kvs[i] = .{ full_field.name, full_field };
        }

        break :blk kvs;
    };
    const full_fields_map = std.static_string_map.StaticStringMap(std.builtin.Type.StructField).initComptime(full_fields_kvs);

    var fields: [field_names.len]std.builtin.Type.StructField = undefined;

    for (field_names, 0..) |field_name, i| {
        const field = full_fields_map.get(field_name) orelse {
            @compileError("Field '" ++ field_name ++ "' not found in FullData");
        };

        fields[i] = field;
        fields[i].alignment = 0; // Required for packed structs
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

pub fn Backing(comptime DataType: type, comptime backing_type_name: []const u8) type {
    const fields = @typeInfo(DataType).@"struct".fields;

    var backing_arrays: [fields.len]std.builtin.Type.StructField = undefined;
    var backed_fields_len: usize = 0;

    inline for (fields) |field| {
        switch (@typeInfo(field.type)) {
            .@"struct" => {
                if (@hasDecl(field.type, backing_type_name)) {
                    backing_arrays[backed_fields_len] = .{
                        .name = field.name,
                        .type = @FieldType(field.type, backing_type_name),
                    };
                    backed_fields_len += 1;
                }
            },
            else => {},
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = backing_arrays[0..backed_fields_len],
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn ArrayLen(comptime T: type, comptime max_len_: comptime_int) type {
    const Len_ = std.math.IntFittingRange(0, max_len_);

    return struct {
        items: [max_len_]T,
        len: Len_,

        pub const max_len = max_len_;
        pub const Len = Len_;

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
    const Bits = std.meta.Int(.unsigned, item_bits * len);

    return packed struct {
        const Self = @This();

        bits: Bits,

        pub const Array = ArrayLen(T, len);

        pub fn fromSlice(slice: []const T) Self {
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

pub fn OffsetLen(
    comptime T: type,
    comptime max_len: comptime_int,
    comptime max_offset: comptime_int,
    comptime embedded_len: comptime_int,
) type {
    const Offset = std.math.IntFittingRange(0, max_offset);
    const Len = std.math.IntFittingRange(0, max_len);
    const EmbeddedArray = PackedArray(T, embedded_len);

    return packed struct {
        data: packed union {
            embedded: EmbeddedArray,
            offset: Offset,
        },
        len: Len,

        pub const EmbeddedArrayLen = ArrayLen(T, embedded_len);
        pub const BackingArrayLen = ArrayLen(T, max_offset);
        pub const BackingOffsetMap = OffsetMap(T, Offset);

        fn fromSlice(
            allocator: std.mem.Allocator,
            backing: *BackingArrayLen,
            map: BackingOffsetMap,
            slice: []const T,
        ) @This() {
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
                if (gop.found_existing) |offset| {
                    return .{
                        .len = len,
                        .data = .{
                            .offset = offset,
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

        fn toSlice(self: @This(), backing: BackingArrayLen, buffer: *EmbeddedArrayLen) []const T {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else

            if (comptime embedded_len == max_len) {
                return self.data.toArray(buffer)[0..self.len];
            } else if (comptime embedded_len == 0) {
                return backing.items[self.data.offset .. self.data.offset + self.len];
            } else if (self.len <= embedded_len) {
                return self.data.toArray(buffer)[0..self.len];
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
            return std.hash_map.hashString(std.mem.sliceAsBytes(s));
        }
        pub fn eql(self: @This(), a: []const T, b: []const T) bool {
            _ = self;
            return std.mem.eql(T, a, b);
        }
    }, std.hash_map.default_max_load_percentage);
}

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
    iso_comment: []const u8,
    simple_uppercase_mapping: ?u21,
    simple_lowercase_mapping: ?u21,
    simple_titlecase_mapping: ?u21,
};

pub const CaseFolding = struct {
    simple: u21 = 0,
    turkish: ?u21 = null,
    full: [3]u21 = .{ 0, 0, 0 },
    full_len: u2 = 0,
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
