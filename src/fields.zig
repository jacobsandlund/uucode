const config = @import("config.zig");
const types = @import("types.zig");

pub const fields: []const config.Field = &.{
    // UnicodeData
    .{
        .name = "name",
        .type = []const u8,
        .max_len = 88,
        .max_offset = 1041131,
        .embedded_len = 2,
    },
    .{ .name = "general_category", .type = types.GeneralCategory },
    .{ .name = "canonical_combining_class", .type = u8 },
    .{ .name = "bidi_class", .type = types.BidiClass },
    .{ .name = "decomposition_type", .type = types.DecompositionType },
    .{
        .name = "decomposition_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -181519,
        .shift_high = 99324,
        .max_len = 18,
        .max_offset = 4602,
        .embedded_len = 0,
    },
    .{ .name = "numeric_type", .type = types.NumericType },
    .{
        .name = "numeric_value_decimal",
        .type = ?u4,
        .min_value = 0,
        .max_value = 9,
    },
    .{
        .name = "numeric_value_digit",
        .type = ?u4,
        .min_value = 0,
        .max_value = 9,
    },
    .{
        .name = "numeric_value_numeric",
        .type = []const u8,
        .max_len = 13,
        .max_offset = 503,
        .embedded_len = 1,
    },
    .{ .name = "is_bidi_mirrored", .type = bool },
    .{
        .name = "unicode_1_name",
        .type = []const u8,
        .max_len = 55,
        .max_offset = 49956,
        .embedded_len = 0,
    },
    .{
        .name = "simple_uppercase_mapping",
        .type = u21,
        .cp_packing = .shift,
        .shift_low = -38864,
        .shift_high = 42561,
    },
    .{
        .name = "simple_lowercase_mapping",
        .type = u21,
        .cp_packing = .shift,
        .shift_low = -42561,
        .shift_high = 38864,
    },
    .{
        .name = "simple_titlecase_mapping",
        .type = u21,
        .cp_packing = .shift,
        .shift_low = -38864,
        .shift_high = 42561,
    },

    // CaseFolding
    .{
        .name = "case_folding_simple",
        .type = u21,
        .cp_packing = .shift,
        .shift_low = -42561,
        .shift_high = 35267,
    },
    .{
        .name = "case_folding_full",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -42561,
        .shift_high = 35267,
        .max_len = 3,
        .max_offset = 160,
        .embedded_len = 0,
    },
    .{
        .name = "case_folding_turkish_only",
        .type = ?u21,
        .cp_packing = .shift,
        .shift_low = -199,
        .shift_high = 232,
    },
    .{
        .name = "case_folding_common_only",
        .type = ?u21,
        .cp_packing = .shift,
        .shift_low = -42561,
        .shift_high = 35267,
    },
    .{
        .name = "case_folding_simple_only",
        .type = ?u21,
        .cp_packing = .shift,
        .shift_low = -7615,
        .shift_high = 1,
    },
    .{
        .name = "case_folding_full_only",
        .type = []const u21,
        .cp_packing = .direct,
        .max_len = 3,
        .max_offset = 160,
        .embedded_len = 0,
    },

    // SpecialCasing
    .{ .name = "has_special_casing", .type = bool },
    .{
        .name = "special_lowercase_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -9,
        .shift_high = 0,
        .max_len = 2,
        .max_offset = 2,
        .embedded_len = 0,
    },
    .{
        .name = "special_titlecase_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = 0,
        .shift_high = 9,
        .max_len = 3,
        .max_offset = 104,
        .embedded_len = 0,
    },
    .{
        .name = "special_uppercase_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = 0,
        .shift_high = 0,
        .max_len = 3,
        .max_offset = 158,
        .embedded_len = 0,
    },
    .{
        .name = "special_casing_condition",
        .type = []const types.SpecialCasingCondition,
        .max_len = 2,
        .max_offset = 12,
        .embedded_len = 1,
    },
    .{
        .name = "special_lowercase_mapping_conditional",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -199,
        .shift_high = 232,
        .max_len = 3,
        .max_offset = 15,
        .embedded_len = 0,
    },
    .{
        .name = "special_titlecase_mapping_conditional",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = 0,
        .shift_high = 199,
        .max_len = 1,
        .max_offset = 0,
        .embedded_len = 0,
    },
    .{
        .name = "special_uppercase_mapping_conditional",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = 0,
        .shift_high = 199,
        .max_len = 1,
        .max_offset = 0,
        .embedded_len = 0,
    },

    // Case mappings
    .{
        .name = "lowercase_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -42561,
        .shift_high = 38864,
        .max_len = 1,
        .max_offset = 0,
        .embedded_len = 0,
    },
    .{
        .name = "titlecase_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -38864,
        .shift_high = 42561,
        .max_len = 3,
        .max_offset = 104,
        .embedded_len = 0,
    },
    .{
        .name = "uppercase_mapping",
        .type = []const u21,
        .cp_packing = .shift,
        .shift_low = -38864,
        .shift_high = 42561,
        .max_len = 3,
        .max_offset = 158,
        .embedded_len = 0,
    },

    // DerivedCoreProperties
    .{ .name = "is_math", .type = bool },
    .{ .name = "is_alphabetic", .type = bool },
    .{ .name = "is_lowercase", .type = bool },
    .{ .name = "is_uppercase", .type = bool },
    .{ .name = "is_cased", .type = bool },
    .{ .name = "is_case_ignorable", .type = bool },
    .{ .name = "changes_when_lowercased", .type = bool },
    .{ .name = "changes_when_uppercased", .type = bool },
    .{ .name = "changes_when_titlecased", .type = bool },
    .{ .name = "changes_when_casefolded", .type = bool },
    .{ .name = "changes_when_casemapped", .type = bool },
    .{ .name = "is_id_start", .type = bool },
    .{ .name = "is_id_continue", .type = bool },
    .{ .name = "is_xid_start", .type = bool },
    .{ .name = "is_xid_continue", .type = bool },
    .{ .name = "is_default_ignorable", .type = bool },
    .{ .name = "is_grapheme_extend", .type = bool },
    .{ .name = "is_grapheme_base", .type = bool },
    .{ .name = "is_grapheme_link", .type = bool },
    .{ .name = "indic_conjunct_break", .type = types.IndicConjunctBreak },

    // EastAsianWidth
    .{ .name = "east_asian_width", .type = types.EastAsianWidth },

    // OriginalGraphemeBreak
    // This is the field from GraphemeBreakProperty.txt, without combining
    // `indic_conjunct_break`, `is_emoji_modifier`,
    // `is_emoji_modifier_base`, and `is_extended_pictographic`
    .{ .name = "original_grapheme_break", .type = types.OriginalGraphemeBreak },

    // EmojiData
    .{ .name = "is_emoji", .type = bool },
    .{ .name = "is_emoji_presentation", .type = bool },
    .{ .name = "is_emoji_modifier", .type = bool },
    .{ .name = "is_emoji_modifier_base", .type = bool },
    .{ .name = "is_emoji_component", .type = bool },
    .{ .name = "is_extended_pictographic", .type = bool },

    // EmojiVs
    // `emoji-variation-sequences.txt` and UTS #51 split out the emoji and text
    // variation sequences separately. However, ever since these were
    // introduced in Unicode 6.1 (see
    // https://unicode.org/Public/6.1.0/ucd/StandardizedVariants.txt--dated
    // 2011-11-10), until present, there has never been an emoji variation
    // sequence that isn't also a valid text variation sequence, and vice
    // versa, this is just a single `is_emoji_vs_base`. Also the "Total
    // sequences" comment at the end of emoji-variation-sequences.txt counts
    // the number of sequences as one per base code point, rather than counting
    // the "emoji style" and "text style" lines separately.
    .{ .name = "is_emoji_vs_base", .type = bool },

    // GraphemeBreak (derived)
    // This is derived from `original_grapheme_break`
    // (GraphemeBreakProperty.txt), `indic_conjunct_break`,
    // `is_emoji_modifier`, `is_emoji_modifier_base`, and
    // `is_extended_pictographic`
    .{ .name = "grapheme_break", .type = types.GraphemeBreak },

    // BidiPairedBracket
    .{
        .name = "bidi_paired_bracket",
        .type = types.BidiPairedBracket,
        .cp_packing = .shift,
        .shift_low = -3,
        .shift_high = 3,
    },

    // BidiMirroring
    .{
        .name = "bidi_mirroring",
        .type = ?u21,
        .cp_packing = .shift,
        .shift_low = -2527,
        .shift_high = 2527,
    },

    // Block
    .{ .name = "block", .type = types.Block },

    // Script
    .{ .name = "script", .type = types.Script },

    // Joining Type
    .{ .name = "joining_type", .type = types.JoiningType },

    // Joining Group
    .{ .name = "joining_group", .type = types.JoiningGroup },

    // Composition Exclusions
    .{ .name = "is_composition_exclusion", .type = bool },

    // Indic Positional Category
    .{ .name = "indic_positional_category", .type = types.IndicPositionalCategory },

    // Indic Syllabic Category
    .{ .name = "indic_syllabic_category", .type = types.IndicSyllabicCategory },

    // GraphemeBreakNoControl (derived from grapheme_break)
    .{ .name = "grapheme_break_no_control", .type = types.GraphemeBreakNoControl },

    // Wcwidth (derived)
    .{ .name = "wcwidth_standalone", .type = u2 },
    .{ .name = "wcwidth_zero_in_grapheme", .type = bool },
};
