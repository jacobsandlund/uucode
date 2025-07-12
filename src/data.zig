const std = @import("std");

pub const min_code_point: u21 = 0x0000;
pub const max_code_point: u21 = 0x10FFFF;
pub const num_code_points: u21 = max_code_point + 1;
pub const code_point_range_end: u21 = max_code_point + 1;

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
    iso_comment: []const u8,
    simple_uppercase_mapping: ?u21,
    simple_lowercase_mapping: ?u21,
    simple_titlecase_mapping: ?u21,

    // CaseFolding fields
    case_folding_simple: u21 = 0,
    case_folding_turkish: ?u21 = null,
    case_folding_full: [3]u21 = .{ 0, 0, 0 },
    case_folding_full_len: u2 = 0,

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

pub const GeneralCategory = enum {
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

pub const BidiClass = enum {
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

pub const DecompositionType = enum {
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

pub const NumericType = enum {
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

pub const IndicConjunctBreak = enum {
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

pub const EastAsianWidth = enum {
    neutral,
    fullwidth,
    halfwidth,
    wide,
    narrow,
    ambiguous,
};

pub const GraphemeBreak = enum {
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
