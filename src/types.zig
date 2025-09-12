const std = @import("std");
const config = @import("config.zig");

pub const GeneralCategory = enum(u5) {
    letter_uppercase, // Lu
    letter_lowercase, // Ll
    letter_titlecase, // Lt
    letter_modifier, // Lm
    letter_other, // Lo
    mark_nonspacing, // Mn
    mark_spacing_combining, // Mc
    mark_enclosing, // Me
    number_decimal_digit, // Nd
    number_letter, // Nl
    number_other, // No
    punctuation_connector, // Pc
    punctuation_dash, // Pd
    punctuation_open, // Ps
    punctuation_close, // Pe
    punctuation_initial_quote, // Pi
    punctuation_final_quote, // Pf
    punctuation_other, // Po
    symbol_math, // Sm
    symbol_currency, // Sc
    symbol_modifier, // Sk
    symbol_other, // So
    separator_space, // Zs
    separator_line, // Zl
    separator_paragraph, // Zp
    other_control, // Cc
    other_format, // Cf
    other_surrogate, // Cs
    other_private_use, // Co
    other_not_assigned, // Cn
};

// TODO: actually parse `DerivedBidiClass.txt`
pub const BidiClass = enum(u5) {
    left_to_right, // L
    left_to_right_embedding, // LRE
    left_to_right_override, // LRO
    right_to_left, // R
    right_to_left_arabic, // AL
    right_to_left_embedding, // RLE
    right_to_left_override, // RLO
    pop_directional_format, // PDF
    european_number, // EN
    european_number_separator, // ES
    european_number_terminator, // ET
    arabic_number, // AN
    common_number_separator, // CS
    nonspacing_mark, // NSM
    boundary_neutral, // BN
    paragraph_separator, // B
    segment_separator, // S
    whitespace, // WS
    other_neutrals, // ON
    left_to_right_isolate, // LRI
    right_to_left_isolate, // RLI
    first_strong_isolate, // FSI
    pop_directional_isolate, // PDI
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

pub const IndicConjunctBreak = enum(u2) {
    none,
    linker,
    consonant,
    extend,
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
    spacing_mark,
    l,
    v,
    t,
    lv,
    lvt,
    zwj,
};

pub const GraphemeBreak = enum(u5) {
    other,
    control,
    prepend,
    cr,
    lf,
    regional_indicator,
    spacing_mark,
    l,
    v,
    t,
    lv,
    lvt,
    zwj,
    zwnj,
    extended_pictographic,
    // extend, ==
    //   zwnj +
    //   indic_conjunct_break_extend +
    //   indic_conjunct_break_linker
    indic_conjunct_break_extend,
    indic_conjunct_break_linker,
    indic_conjunct_break_consonant,
};

pub const zero_width_non_joiner = 0x200C;
pub const zero_width_joiner = 0x200D;

pub const SpecialCasingCondition = enum(u4) {
    none,
    final_sigma,
    after_soft_dotted,
    more_above,
    after_i,
    not_before_dot,
    lt,
    tr,
    az,
};

pub const Block = enum(u9) {
    adlam,
    aegean_numbers,
    ahom,
    alchemical_symbols,
    alphabetic_presentation_forms,
    anatolian_hieroglyphs,
    ancient_greek_musical_notation,
    ancient_greek_numbers,
    ancient_symbols,
    arabic,
    arabic_extended_a,
    arabic_extended_b,
    arabic_extended_c,
    arabic_mathematical_alphabetic_symbols,
    arabic_presentation_forms_a,
    arabic_presentation_forms_b,
    arabic_supplement,
    armenian,
    arrows,
    avestan,
    balinese,
    bamum,
    bamum_supplement,
    basic_latin,
    bassa_vah,
    batak,
    bengali,
    bhaiksuki,
    block_elements,
    bopomofo,
    bopomofo_extended,
    box_drawing,
    brahmi,
    braille_patterns,
    buginese,
    buhid,
    byzantine_musical_symbols,
    carian,
    caucasian_albanian,
    chakma,
    cham,
    cherokee,
    cherokee_supplement,
    chess_symbols,
    chorasmian,
    cjk_compatibility,
    cjk_compatibility_forms,
    cjk_compatibility_ideographs,
    cjk_compatibility_ideographs_supplement,
    cjk_radicals_supplement,
    cjk_strokes,
    cjk_symbols_and_punctuation,
    cjk_unified_ideographs,
    cjk_unified_ideographs_extension_a,
    cjk_unified_ideographs_extension_b,
    cjk_unified_ideographs_extension_c,
    cjk_unified_ideographs_extension_d,
    cjk_unified_ideographs_extension_e,
    cjk_unified_ideographs_extension_f,
    cjk_unified_ideographs_extension_g,
    cjk_unified_ideographs_extension_h,
    cjk_unified_ideographs_extension_i,
    combining_diacritical_marks,
    combining_diacritical_marks_extended,
    combining_diacritical_marks_for_symbols,
    combining_diacritical_marks_supplement,
    combining_half_marks,
    common_indic_number_forms,
    control_pictures,
    coptic,
    coptic_epact_numbers,
    counting_rod_numerals,
    cuneiform,
    cuneiform_numbers_and_punctuation,
    currency_symbols,
    cypriot_syllabary,
    cypro_minoan,
    cyrillic,
    cyrillic_extended_a,
    cyrillic_extended_b,
    cyrillic_extended_c,
    cyrillic_extended_d,
    cyrillic_supplement,
    deseret,
    devanagari,
    devanagari_extended,
    devanagari_extended_a,
    dingbats,
    dives_akuru,
    dogra,
    domino_tiles,
    duployan,
    early_dynastic_cuneiform,
    egyptian_hieroglyph_format_controls,
    egyptian_hieroglyphs,
    egyptian_hieroglyphs_extended_a,
    elbasan,
    elymaic,
    emoticons,
    enclosed_alphanumeric_supplement,
    enclosed_alphanumerics,
    enclosed_cjk_letters_and_months,
    enclosed_ideographic_supplement,
    ethiopic,
    ethiopic_extended,
    ethiopic_extended_a,
    ethiopic_extended_b,
    ethiopic_supplement,
    garay,
    general_punctuation,
    geometric_shapes,
    geometric_shapes_extended,
    georgian,
    georgian_extended,
    georgian_supplement,
    glagolitic,
    glagolitic_supplement,
    gothic,
    grantha,
    greek_and_coptic,
    greek_extended,
    gujarati,
    gunjala_gondi,
    gurmukhi,
    gurung_khema,
    halfwidth_and_fullwidth_forms,
    hangul_compatibility_jamo,
    hangul_jamo,
    hangul_jamo_extended_a,
    hangul_jamo_extended_b,
    hangul_syllables,
    hanifi_rohingya,
    hanunoo,
    hatran,
    hebrew,
    high_private_use_surrogates,
    high_surrogates,
    hiragana,
    ideographic_description_characters,
    ideographic_symbols_and_punctuation,
    imperial_aramaic,
    indic_siyaq_numbers,
    inscriptional_pahlavi,
    inscriptional_parthian,
    ipa_extensions,
    javanese,
    kaithi,
    kaktovik_numerals,
    kana_extended_a,
    kana_extended_b,
    kana_supplement,
    kanbun,
    kangxi_radicals,
    kannada,
    katakana,
    katakana_phonetic_extensions,
    kawi,
    kayah_li,
    kharoshthi,
    khitan_small_script,
    khmer,
    khmer_symbols,
    khojki,
    khudawadi,
    kirat_rai,
    lao,
    latin_1_supplement,
    latin_extended_a,
    latin_extended_additional,
    latin_extended_b,
    latin_extended_c,
    latin_extended_d,
    latin_extended_e,
    latin_extended_f,
    latin_extended_g,
    lepcha,
    letterlike_symbols,
    limbu,
    linear_a,
    linear_b_ideograms,
    linear_b_syllabary,
    lisu,
    lisu_supplement,
    low_surrogates,
    lycian,
    lydian,
    mahajani,
    mahjong_tiles,
    makasar,
    malayalam,
    mandaic,
    manichaean,
    marchen,
    masaram_gondi,
    mathematical_alphanumeric_symbols,
    mathematical_operators,
    mayan_numerals,
    medefaidrin,
    meetei_mayek,
    meetei_mayek_extensions,
    mende_kikakui,
    meroitic_cursive,
    meroitic_hieroglyphs,
    miao,
    miscellaneous_mathematical_symbols_a,
    miscellaneous_mathematical_symbols_b,
    miscellaneous_symbols,
    miscellaneous_symbols_and_arrows,
    miscellaneous_symbols_and_pictographs,
    miscellaneous_technical,
    modi,
    modifier_tone_letters,
    mongolian,
    mongolian_supplement,
    mro,
    multani,
    musical_symbols,
    myanmar,
    myanmar_extended_a,
    myanmar_extended_b,
    myanmar_extended_c,
    nabataean,
    nag_mundari,
    nandinagari,
    new_tai_lue,
    newa,
    nko,
    no_block,
    number_forms,
    nushu,
    nyiakeng_puachue_hmong,
    ogham,
    ol_chiki,
    ol_onal,
    old_hungarian,
    old_italic,
    old_north_arabian,
    old_permic,
    old_persian,
    old_sogdian,
    old_south_arabian,
    old_turkic,
    old_uyghur,
    optical_character_recognition,
    oriya,
    ornamental_dingbats,
    osage,
    osmanya,
    ottoman_siyaq_numbers,
    pahawh_hmong,
    palmyrene,
    pau_cin_hau,
    phags_pa,
    phaistos_disc,
    phoenician,
    phonetic_extensions,
    phonetic_extensions_supplement,
    playing_cards,
    private_use_area,
    psalter_pahlavi,
    rejang,
    rumi_numeral_symbols,
    runic,
    samaritan,
    saurashtra,
    sharada,
    shavian,
    shorthand_format_controls,
    siddham,
    sinhala,
    sinhala_archaic_numbers,
    small_form_variants,
    small_kana_extension,
    sogdian,
    sora_sompeng,
    soyombo,
    spacing_modifier_letters,
    specials,
    sundanese,
    sundanese_supplement,
    sunuwar,
    superscripts_and_subscripts,
    supplemental_arrows_a,
    supplemental_arrows_b,
    supplemental_arrows_c,
    supplemental_mathematical_operators,
    supplemental_punctuation,
    supplemental_symbols_and_pictographs,
    supplementary_private_use_area_a,
    supplementary_private_use_area_b,
    sutton_signwriting,
    syloti_nagri,
    symbols_and_pictographs_extended_a,
    symbols_for_legacy_computing,
    symbols_for_legacy_computing_supplement,
    syriac,
    syriac_supplement,
    tagalog,
    tagbanwa,
    tags,
    tai_le,
    tai_tham,
    tai_viet,
    tai_xuan_jing_symbols,
    takri,
    tamil,
    tamil_supplement,
    tangsa,
    tangut,
    tangut_components,
    tangut_supplement,
    telugu,
    thaana,
    thai,
    tibetan,
    tifinagh,
    tirhuta,
    todhri,
    toto,
    transport_and_map_symbols,
    tulu_tigalari,
    ugaritic,
    unified_canadian_aboriginal_syllabics,
    unified_canadian_aboriginal_syllabics_extended,
    unified_canadian_aboriginal_syllabics_extended_a,
    vai,
    variation_selectors,
    variation_selectors_supplement,
    vedic_extensions,
    vertical_forms,
    vithkuqi,
    wancho,
    warang_citi,
    yezidi,
    yi_radicals,
    yi_syllables,
    yijing_hexagram_symbols,
    zanabazar_square,
    znamenny_musical_notation,
};

// The following types are internal to `uucode`:

pub fn Field(c: config.Field) type {
    return switch (c.kind()) {
        .var_len => VarLen(c),
        .shift => Shift(c),
        .basic, .optional => c.type,
    };
}

pub fn Data(comptime c: config.Table) type {
    var data_fields: [c.fields.len]std.builtin.Type.StructField = undefined;

    for (c.fields, 0..) |cf, i| {
        const F = Field(cf);

        data_fields[i] = .{
            .name = cf.name,
            .type = F,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(F),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &data_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn writeData(comptime D: type, writer: *std.Io.Writer, data: D) !void {
    try writer.writeAll(
        \\.{
        \\
    );

    inline for (@typeInfo(D).@"struct".fields) |field| {
        try writer.print("    .{s} = ", .{field.name});

        try writeDataField(field.type, writer, @field(data, field.name));

        try writer.writeAll(",\n");
    }

    try writer.writeAll(
        \\},
        \\
    );
}

pub fn writeDataField(comptime F: type, writer: *std.Io.Writer, field: F) !void {
    switch (@typeInfo(F)) {
        .@"struct" => {
            try field.write(writer);
        },
        .@"enum" => {
            try writer.print(".{s}", .{@tagName(field)});
        },
        else => {
            try writer.print("{}", .{field});
        },
    }
}

pub fn Backing(comptime D: type) type {
    return StructFromDecls(D, "BackingBuffer");
}

pub fn Table3(
    comptime Data_: type,
    comptime Backing_: type,
) type {
    return struct {
        stage1: []const u16,
        stage2: []const u16,
        stage3: []const Data_,
        backing: *const Backing_,
    };
}

pub fn Table2(
    comptime Data_: type,
    comptime Backing_: type,
) type {
    return struct {
        stage1: []const u16,
        stage2: []const Data_,
        backing: *const Backing_,
    };
}

pub fn StructFromDecls(comptime Struct: type, comptime decl: []const u8) type {
    var decl_fields_len: usize = 0;
    for (@typeInfo(Struct).@"struct".fields) |f| {
        if (@typeInfo(f.type) == .@"struct" and @hasDecl(f.type, decl)) {
            decl_fields_len += 1;
        }
    }

    var decl_fields: [decl_fields_len]std.builtin.Type.StructField = undefined;
    var i: usize = 0;

    for (@typeInfo(Struct).@"struct".fields) |f| {
        if (@typeInfo(f.type) == .@"struct" and @hasDecl(f.type, decl)) {
            const T = @field(f.type, decl);
            decl_fields[i] = .{
                .name = f.name,
                .type = T,
                .default_value_ptr = null, // TODO: can we set this?
                .is_comptime = false,
                .alignment = @alignOf(T),
            };
            i += 1;
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &decl_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn VarLen(
    comptime c: config.Field,
) type {
    const max_len = c.max_len;
    const max_offset = c.max_offset;
    const embedded_len = c.embedded_len;

    if (max_len == 0) {
        @compileError("VarLen with max_len == 0 is not supported due to Zig compiler bug");
    }

    if (max_offset == 0 and !(embedded_len == max_len or
        (max_len == 1 and c.cp_packing == .shift_single_item)))
    {
        @compileError("VarLen with max_offset == 0 is only supported if embedded_len is max_len, or max_len is 1 with shift_single_item");
    }

    if (c.cp_packing == .shift) {
        @compileError("`shift` packing is not supported for VarLen: use `shift_single_item` or `direct` instead");
    }

    return struct {
        data: union {
            offset: Offset,
            embedded: EmbeddedArray,
            shift: ShiftSingleItem,
        },
        len: Len,

        const Self = @This();
        pub const T = @typeInfo(c.type).pointer.child;
        pub const Offset = std.math.IntFittingRange(0, max_offset);
        const EmbeddedArray = [embedded_len]T;
        const ShiftSingleItem = if (c.cp_packing == .shift_single_item) Shift(c) else void;

        const Len = std.math.IntFittingRange(0, max_len);

        pub const empty = Self{ .len = 0, .data = .{ .offset = 0 } };

        pub const Tracking = VarLenTracking(T, max_len);

        pub const SliceBuffer = [
            @max(
                embedded_len,
                @intFromBool(c.cp_packing == .shift_single_item),
            )
        ]T;
        pub const CopyBuffer = [max_len]T;
        pub const BackingBuffer = []const T;
        pub const MutableBackingBuffer = []T;

        inline fn _fromSlice(
            allocator: std.mem.Allocator,
            backing: []T,
            tracking: *Tracking,
            s: []const T,
        ) !Self {
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

                const offset = tracking.max_offset;
                gop.value_ptr.* = offset;
                @memcpy(backing[offset .. offset + s.len], s);
                gop.key_ptr.* = backing[offset .. offset + s.len];
                tracking.len_counts[s.len - 1] += 1;
                tracking.max_offset += s.len;

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

        pub fn fromSlice(
            allocator: std.mem.Allocator,
            backing: []T,
            tracking: *Tracking,
            s: []const T,
        ) !Self {
            if (c.cp_packing != .direct) {
                @compileError("fromSlice is only supported for direct packing: use fromSliceFor instead");
            }

            return ._fromSlice(allocator, backing, tracking, s);
        }

        pub fn fromSliceFor(
            allocator: std.mem.Allocator,
            backing: []T,
            tracking: *Tracking,
            s: []const T,
            cp: u21,
        ) !Self {
            if (s.len == 1) {
                tracking.shift.track(cp, s[0]);
            }

            if (c.cp_packing == .shift_single_item and s.len == 1) {
                return .{
                    .len = 1,
                    .data = .{
                        .shift = .initUntracked(cp, s[0]),
                    },
                };
            } else {
                return ._fromSlice(allocator, backing, tracking, s);
            }
        }

        fn directSlice(
            self: *const Self,
            backing: []const T,
            buffer: []T,
        ) []const T {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            if (comptime embedded_len == max_len) {
                @memcpy(buffer[0..self.len], self.data.embedded[0..self.len]);
                return buffer[0..self.len];
            } else if (comptime embedded_len == 0) {
                return backing[self.data.offset .. @as(usize, self.data.offset) + @as(usize, self.len)];
            } else if (self.len <= embedded_len) {
                @memcpy(buffer[0..self.len], self.data.embedded[0..self.len]);
                return buffer[0..self.len];
            } else {
                return backing[self.data.offset .. @as(usize, self.data.offset) + @as(usize, self.len)];
            }
        }

        pub fn sliceWithBacking(
            self: *const Self,
            backing: []const T,
            buffer: []T,
        ) []const T {
            if (c.cp_packing != .direct) {
                @compileError("sliceWithBacking is only supported for direct packing: use sliceForWithBacking instead");
            }

            return self.directSlice(backing, buffer);
        }

        pub fn sliceForWithBacking(
            self: *const Self,
            backing: []const T,
            buffer: []T,
            cp: u21,
        ) []const T {
            switch (c.cp_packing) {
                .shift_single_item => {
                    if (self.len == 1) {
                        buffer[0] = self.data.shift.value(cp);
                        return buffer[0..1];
                    } else {
                        return self.directSlice(backing, buffer);
                    }
                },
                .direct => return self.directSlice(backing, buffer),
                .shift => unreachable,
            }
        }

        // Note: while it would be better for modularity to pass `backing`
        // in, this makes for a nicer API without having to wrap VarLen.
        const hardcoded_backing = @import("get.zig").backingFor(c.name);

        fn _slice(self: *const Self, buffer: []T) []const T {
            return self.sliceWithBacking(hardcoded_backing, buffer);
        }

        fn _sliceFor(
            self: *const Self,
            buffer: []T,
            cp: u21,
        ) []const T {
            return self.sliceForWithBacking(hardcoded_backing, buffer, cp);
        }

        pub const slice = if (c.cp_packing == .direct)
            _slice
        else
            _sliceFor;

        fn lazyMemcpy(dest: []T, source: []const T) []const T {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            if (comptime embedded_len == max_len) {
                return source;
            } else if (comptime embedded_len == 0 and c.cp_packing == .direct) {
                const d = dest[0..source.len];
                @memcpy(d, source);
                return d;
            } else if (source.len <= embedded_len or (c.cp_packing == .shift_single_item and source.len == 1)) {
                return source;
            } else {
                const d = dest[0..source.len];
                @memcpy(d, source);
                return d;
            }
        }

        fn _copy(self: *const Self, dest: []T) []const T {
            return lazyMemcpy(dest, self._slice(dest));
        }

        fn _copyFor(self: *const Self, dest: []T, cp: u21) []const T {
            return lazyMemcpy(dest, self._sliceFor(dest, cp));
        }

        pub const copy = if (c.cp_packing == .direct)
            _copy
        else
            _copyFor;

        fn _array(self: *const Self) [max_len]T {
            var a: [max_len]T = undefined;
            const s = lazyMemcpy(&a, self._slice(&a));
            @memset(a[s.len..], 0);
            return a;
        }

        fn _arrayFor(self: *const Self, cp: u21) [max_len]T {
            var a: [max_len]T = undefined;
            const s = lazyMemcpy(&a, self._sliceFor(&a, cp));
            @memset(a[s.len..], 0);
            return a;
        }

        pub const array = if (c.cp_packing == .direct)
            _array
        else
            _arrayFor;

        pub fn autoHash(self: Self, hasher: anytype) void {
            // Repeat the two return cases, first with two `comptime` checks,
            // then with a runtime if/else
            std.hash.autoHash(hasher, self.len);
            if ((comptime c.cp_packing == .shift_single_item) and self.len == 1) {
                return std.hash.autoHash(hasher, self.data.shift);
            } else if ((comptime embedded_len == 0) or self.len > embedded_len) {
                return std.hash.autoHash(hasher, self.data.offset);
            } else {
                return std.hash.autoHash(hasher, self.data.embedded);
            }
        }

        pub fn eql(a: Self, b: Self) bool {
            if (a.len != b.len) {
                return false;
            }
            if ((comptime c.cp_packing == .shift_single_item) and a.len == 1) {
                return a.data.shift.eql(b.data.shift);
            } else if ((comptime embedded_len == 0) or a.len > embedded_len) {
                return a.data.offset == b.data.offset;
            } else {
                return std.mem.eql(T, &a.data.embedded, &b.data.embedded);
            }
        }

        pub fn write(self: Self, writer: *std.Io.Writer) !void {
            try writer.print(
                \\.{{
                \\    .len = {},
                \\
            , .{self.len});

            if ((comptime c.cp_packing == .shift_single_item) and self.len == 1) {
                try writer.writeAll("    .data = .{ .shift = ");
                try self.data.shift.write(writer);
                try writer.writeAll("},\n");
            } else if ((comptime embedded_len == 0) or self.len > embedded_len) {
                try writer.print(
                    \\    .data = .{{ .offset = {} }},
                    \\
                , .{self.data.offset});
            } else {
                try writer.writeAll(
                    \\    .data = .{ .embedded = .{
                );
                for (self.data.embedded) |item| {
                    try writeDataField(T, writer, item);
                    try writer.writeAll(",");
                }
                try writer.writeAll(
                    \\} },
                    \\
                );
            }

            try writer.writeAll(
                \\}
                \\
            );
        }
    };
}

pub fn VarLenTracking(comptime T: type, comptime max_len: usize) type {
    return struct {
        max_offset: usize = 0,
        offset_map: SliceMap(T, usize) = .empty,
        len_counts: [max_len]usize = [_]usize{0} ** max_len,
        shift: ShiftTracking = .{},

        const Self = @This();

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.offset_map.deinit(allocator);
        }

        pub fn actualConfig(
            self: *const Self,
            c: config.Field.Runtime,
        ) config.Field.Runtime {
            var i = max_len;
            const actual_max_len: usize = while (i != 0) : (i -= 1) {
                if (self.len_counts[i - 1] != 0) {
                    break i;
                }
            } else (if (c.cp_packing == .shift_single_item) 1 else 0);

            return c.override(.{
                .shift_low = self.shift.shift_low,
                .shift_high = self.shift.shift_high,
                .max_len = actual_max_len,
                .max_offset = self.max_offset,
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
            if (actual.max_len == 0 or actual.max_len == 1 and self.len_counts[0] == 0) {
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

            std.debug.assert(current_max_offset == self.max_offset);

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

    pub fn deinit(self: *ShiftTracking, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn track(self: *ShiftTracking, cp: u21, d: u21) void {
        const shift = @as(isize, d) - @as(isize, cp);
        if (self.shift_high < shift) {
            self.shift_high = shift;
        } else if (shift < self.shift_low) {
            self.shift_low = shift;
        }
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

// Note: this can only be used for types where the max value isn't a valid
// value, which is the case for all optional types in `config.default`
pub fn PackedOptional(comptime c: config.Field) type {
    return packed struct {
        data: T,

        const Self = @This();

        pub const T = @typeInfo(c.type).optional.child;

        const null_data = std.math.maxInt(T);

        pub const @"null" = Self{ .data = null_data };

        pub fn init(opt: ?T) Self {
            if (opt) |value| {
                std.debug.assert(value != null_data);
                return .{ .data = value };
            } else {
                return .null;
            }
        }

        pub fn optional(self: Self) ?T {
            if (self.data == null_data) {
                return null;
            } else {
                return self.data;
            }
        }

        pub fn write(self: Self, writer: anytype) !void {
            try writer.print(
                \\.{{
                \\    .data = {},
                \\}}
                \\
            , .{self.data});
        }
    };
}

pub fn Shift(comptime c: config.Field) type {
    const is_optional_ = c.kind() == .shift and @typeInfo(c.type) == .optional;

    if (c.kind() == .shift and !((is_optional_ and @typeInfo(c.type).optional.child == u21) or
        c.type == u21))
    {
        @compileError("Shift field '" ++ c.name ++ "' must be type u21 or ?u21");
    }

    if (c.kind() == .var_len and @typeInfo(c.type).pointer.child != u21) {
        @compileError("VarLen field '" ++ c.name ++ "' must be type []const u21");
    }

    return struct {
        data: Int,

        const Self = @This();

        pub const T = u21;
        pub const is_optional = is_optional_;
        const Int = std.math.IntFittingRange(c.shift_low, c.shift_high + @intFromBool(is_optional));

        pub const Tracking = ShiftTracking;

        // Only valid if `is_optional`
        const null_data = std.math.maxInt(Int);
        pub const @"null" = Self{ .data = null_data };

        pub const no_shift = Self{ .data = 0 };

        pub fn initUntracked(cp: u21, d: u21) Self {
            return Self{ .data = @intCast(@as(isize, d) - @as(isize, cp)) };
        }

        pub fn init(tracking: *Tracking, cp: u21, d: u21) Self {
            tracking.track(cp, d);
            return .initUntracked(cp, d);
        }

        pub fn initOptional(tracking: *Tracking, cp: u21, o: ?u21) Self {
            if (o) |d| {
                return .init(tracking, cp, d);
            } else {
                return .null;
            }
        }

        pub fn value(self: Self, cp: u21) u21 {
            return @intCast(@as(isize, cp) + @as(isize, self.data));
        }

        pub fn optional(self: Self, cp: u21) ?u21 {
            if (self.data == null_data) {
                return null;
            } else {
                return self.value(cp);
            }
        }

        pub fn eql(a: Self, b: Self) bool {
            return a.data == b.data;
        }

        pub fn write(self: Self, writer: *std.Io.Writer) !void {
            try writer.print(
                \\.{{
                \\    .data = {},
                \\}}
                \\
            , .{self.data});
        }
    };
}
