const std = @import("std");
const config = @import("config.zig");

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

pub fn UnicodeData(comptime c: config.Table) type {
    return struct {
        name: Field(c.field("name")),
        general_category: Field(c.field("general_category")),
        canonical_combining_class: Field(c.field("canonical_combining_class")),
        bidi_class: Field(c.field("bidi_class")),
        decomposition_type: Field(c.field("decomposition_type")),
        decomposition_mapping: Field(c.field("decomposition_mapping")),
        numeric_type: Field(c.field("numeric_type")),
        numeric_value_decimal: Field(c.field("numeric_value_decimal")),
        numeric_value_digit: Field(c.field("numeric_value_digit")),
        numeric_value_numeric: Field(c.field("numeric_value_numeric")),
        is_bidi_mirrored: Field(c.field("is_bidi_mirrored")),
        unicode_1_name: Field(c.field("unicode_1_name")),
        simple_uppercase_mapping: Field(c.field("simple_uppercase_mapping")),
        simple_lowercase_mapping: Field(c.field("simple_lowercase_mapping")),
        simple_titlecase_mapping: Field(c.field("simple_titlecase_mapping")),
    };
}

pub fn CaseFolding(comptime c: config.Table) type {
    return struct {
        case_folding_simple: Field(c.field("case_folding_simple")),
        case_folding_turkish: Field(c.field("case_folding_turkish")),
        case_folding_full: Field(c.field("case_folding_full")),
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

pub const OriginalGraphemeBreak = enum(u4) {
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

pub const GraphemeBreak = enum(u5) {
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
    emoji_modifier_base,
    emoji_modifier,
    extended_pictographic,
};

pub const EmojiData = struct {
    is_emoji: bool = false,
    has_emoji_presentation: bool = false,
    is_emoji_modifier: bool = false,
    is_emoji_modifier_base: bool = false,
    is_emoji_component: bool = false,
    is_extended_pictographic: bool = false,
};

fn Field(c: config.Table.Field) type {
    return switch (@typeInfo(c.type)) {
        .pointer => OffsetLen(c),
        .optional => PackedOptional(c),
        else => c.type,
    };
}

pub fn Table(comptime c: config.Table) type {
    @setEvalBranchQuota(10_000);
    var data_fields: [c.fields.len + 1]std.builtin.Type.StructField = undefined;
    var data_bit_size: usize = 0;
    var backing_arrays: [c.fields.len]std.builtin.Type.StructField = undefined;
    var backing_len: usize = 0;

    for (c.fields, 0..) |f, i| {
        const F = Field(f);

        if (@typeInfo(f.type) == .pointer) {
            backing_arrays[backing_len] = .{
                .name = f.name,
                .type = F.BackingArray,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(F.BackingArray),
            };
            backing_len += 1;
        }

        data_fields[i] = .{
            .name = f.name,
            .type = F,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = 0, // Required for packed structs
        };
        data_bit_size += @bitSizeOf(F);
    }

    const bits_over_byte = data_bit_size % 8;
    const padding_bits = if (bits_over_byte == 0) 0 else 8 - bits_over_byte;
    data_bit_size += padding_bits;

    data_fields[c.fields.len] = .{
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

    const len: config.Table.Stages.Len = switch (c.stages) {
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

pub fn PackedArray(comptime T: type, comptime capacity: comptime_int) type {
    return packed struct {
        bits: Bits,

        const Self = @This();
        const item_bits = @bitSizeOf(T);
        const Bits = std.meta.Int(.unsigned, item_bits * capacity);
        const ShiftBits = std.math.Log2Int(Bits);

        pub fn fromSlice(s: []const T) Self {
            if ((comptime capacity == 0) or s.len == 0) return .{ .bits = 0 };

            // This may make 1 length slices slightly faster, but it's
            // primarily avoiding an issue where `item_bits` is actually too
            // big to be a valid shift value, and zig can't tell that `i` would
            // never be anything other than 0.
            if (comptime capacity == 1) return .{ .bits = @as(Bits, s[0]) };

            std.debug.assert(s.len <= capacity);
            var bits: Bits = 0;
            for (s, 0..) |item, i| {
                bits |= @as(Bits, item) << item_bits * @as(ShiftBits, @intCast(i));
            }
            return .{ .bits = bits };
        }

        pub fn slice(self: Self, buffer: []T, len: usize) []T {
            inline for (0..capacity) |i| {
                buffer[i] = @as(T, @truncate(self.bits >> item_bits * i));
            }
            return buffer[0..len];
        }
    };
}

pub fn OffsetLen(
    comptime c: config.Table.Field,
) type {
    const T = @typeInfo(c.type).pointer.child;
    const max_len = c.max_len;
    const max_offset = c.max_offset;
    const embedded_len = c.embedded_len;

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

        pub const BackingArray = std.BoundedArray(T, max_offset);
        pub const BackingOffsetMap = OffsetMap(T, Offset);
        pub const BackingLenTracking: type = [max_len]Offset;

        // TODO: also track range of type T, to determine a min T
        pub fn fromSlice(
            allocator: std.mem.Allocator,
            backing: *BackingArray,
            map: *BackingOffsetMap,
            len_tracking: *BackingLenTracking,
            s: []const T,
        ) !Self {
            const len: Len = @intCast(s.len);

            if (comptime embedded_len == 0 and max_offset == 0) {
                return .empty;
            } else if ((comptime embedded_len == max_len) or s.len <= embedded_len) {
                return .{
                    .len = len,
                    .data = .{
                        .embedded = EmbeddedArray.fromSlice(s),
                    },
                };
            } else {
                const gop = try map.getOrPut(allocator, s);
                if (gop.found_existing) {
                    return .{
                        .len = len,
                        .data = .{
                            .offset = gop.value_ptr.*,
                        },
                    };
                }

                const offset: Offset = @intCast(backing.len);
                gop.value_ptr.* = offset;
                backing.appendSliceAssumeCapacity(s);
                gop.key_ptr.* = backing.buffer[offset .. offset + s.len];
                len_tracking[s.len - 1] += 1;

                return .{
                    .len = len,
                    .data = .{
                        .offset = offset,
                    },
                };
            }
        }

        pub fn slice(
            self: *const Self,
            buffer: []T,
        ) []const T {
            // Note: while it would be better for modularity to pass `backing`
            // in, this makes for a nicer API without having to wrap OffsetLen.
            const backing = comptime @field(@import("get.zig").tableFor(c.name).backing, c.name);

            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            if (comptime embedded_len == max_len) {
                return self.data.embedded.slice(buffer, self.len);
            } else if (comptime embedded_len == 0) {
                return backing.constSlice()[self.data.offset .. self.data.offset + self.len];
            } else if (self.len <= embedded_len) {
                return self.data.embedded.slice(buffer, self.len);
            } else {
                return backing.constSlice()[self.data.offset .. self.data.offset + self.len];
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

        pub fn minBitsConfig(
            backing: *BackingArray,
            len_tracking: *BackingLenTracking,
        ) config.Table.Field.OffsetLen {
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
                .name = c.name,
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
                .name = c.name,
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
// value, which is the case for all optional types in `config.default`
pub fn PackedOptional(comptime c: config.Table.Field) type {
    const T = @typeInfo(c.type).optional.child;
    const max = std.math.maxInt(T);

    return packed struct {
        data: T,

        const Self = @This();

        pub const @"null" = Self{ .data = max };

        pub fn fromOptional(opt: ?T) Self {
            if (opt) |value| {
                std.debug.assert(value != max);
                return .{ .data = value };
            } else {
                return .null;
            }
        }

        pub fn optional(self: Self) ?T {
            if (self.data != max) {
                return self.data;
            } else {
                return null;
            }
        }
    };
}
