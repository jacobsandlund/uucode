//! This `x.grapheme.wcwidth` and `x.grapheme.wcwidthString` are the full
//! grapheme cluster calculation of the expected width in cells of a monospaced
//! font. It is not part of the Unicode standard.
//!
//! See `src/x/config_x/wcwidth.zig` for the logic determining the width of a
//! single code point standing alone, as well as a number of notes describing
//! the choices the implementation makes.
//!
//! This implementation makes the following choices:
//!
//! * Only the context of the current grapheme cluster affects the width. The
//!   width of a string of grapheme clusters is the sum of the widths of the
//!   individual clusters.
//!
//! * Grapheme clusters with a single code point simply return
//!   `wcwidth_standalone`. See `src/x/config_x/wcwidth.zig` for all the
//!   considerations determining this value.
//!
//! * The general calculation of the width of a grapheme cluster is the sum of
//!   the widths of the individual code points (clamped to 3), using
//!   `wcwidth_zero_in_grapheme` to treat a code point as width 0 in a multi-
//!   code-point grapheme cluster, otherwise using `wcwidth_standalone` for the
//!   widths of the code points.
//!
//!   Some alternative wcwidth implementations (see resources/wcwidth) only use
//!   the width of the first non-zero width code point, but this does not
//!   properly handle scripts such as Devanagari and Hangul, where multiple
//!   code points in the grapheme cluster may have non-zero width, and the
//!   resulting width is better represented by the sum.
//!
//! * Valid emoji sequences with VS16 (U+FEOF) return width 2, while
//!   valid text sequences with VS15 (U+FE0E) return width 1.
//!
//! * Emoji ZWJ (zero-width joiner) sequences are a special case and the width
//!   of the emoji code points following the ZWJ are not added to the sum.
//!
//! * Regional indicator sequences are given a width of 2.
//!

const std = @import("std");
const uucode = @import("../root.zig");
const types_x = @import("types.x.zig");

fn isExtendedPictographic(gb: uucode.types.GraphemeBreak) bool {
    return gb == .extended_pictographic or gb == .emoji_modifier_base;
}

// This calculates the width of just a single grapheme, advancing the iterator.
// See `wcwidth` for a version that doesn't advance the iterator, and
// `wcwidthString` for a version that calculates the width of a full string.
pub fn wcwidthAdvance(it: anytype) u2 {
    std.debug.assert(@typeInfo(@TypeOf(it)) == .pointer);

    const first = it.nextCodePoint() orelse return 0;

    var prev_cp: u21 = first.code_point;
    const standalone = uucode.get(.wcwidth_standalone, prev_cp);

    if (first.is_break) return standalone;

    var width: u2 = if (uucode.get(.wcwidth_zero_in_grapheme, prev_cp))
        0
    else
        standalone;

    var prev_state: uucode.grapheme.BreakState = it.state;
    std.debug.assert(it.peekCodePoint() != null);

    while (it.nextCodePoint()) |result| {
        var cp = result.code_point;
        if (cp == 0xFE0F) {
            // Emoji presentation selector. Only apply to base code points from
            // emoji variation sequences.
            if (uucode.get(.is_emoji_vs_base, prev_cp)) {
                width = 2;
            }
        } else if (cp == 0xFE0E) {
            // Text presentation selector. Only apply to base code points from
            // emoji variation sequences.
            if (uucode.get(.is_emoji_vs_base, prev_cp)) {
                width = 1;
            }
        } else if (cp == uucode.config.zero_width_joiner and
            prev_state == .extended_pictographic and
            !result.is_break)
        {
            // Make sure Emoji ZWJ sequences collapse to a single emoji by
            // skipping the next emoji base code point.
            const next = it.nextCodePoint() orelse unreachable;
            if (next.is_break) break;
            cp = next.code_point;
        } else if (prev_state == .regional_indicator) {
            width = 2;
        } else {
            if (!uucode.get(.wcwidth_zero_in_grapheme, cp)) {
                const added_width = uucode.get(.wcwidth_standalone, cp);
                if (@as(usize, added_width) + @as(usize, width) > 3) {
                    width = 3;
                } else {
                    width += added_width;
                }
            }
        }

        if (result.is_break) break;

        prev_cp = cp;
        prev_state = it.state;
    }

    return width;
}

pub fn wcwidth(const_it: anytype) u2 {
    var it = const_it;
    return wcwidthAdvance(&it);
}

test "wcwidth ascii" {
    const it1 = uucode.grapheme.utf8Iterator("A");
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it1));
    const it2 = uucode.grapheme.utf8Iterator("1");
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it2));
}

test "wcwidth control, format, surrogate" {
    const it1 = uucode.grapheme.utf8Iterator("\x00");
    try std.testing.expectEqual(@as(u2, 0), wcwidth(it1));
    const it2 = uucode.grapheme.utf8Iterator("\x7F");
    try std.testing.expectEqual(@as(u2, 0), wcwidth(it2));
    const it3 = uucode.grapheme.utf8Iterator("\u{200B}"); // ZWSP
    try std.testing.expectEqual(@as(u2, 0), wcwidth(it3));
}

test "wcwidth marks" {
    const it = uucode.grapheme.utf8Iterator("\u{0300}"); // Mn
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it));
}

test "wcwidth keycap" {
    const it = uucode.grapheme.utf8Iterator("\u{20E3}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth regional indicator standalone" {
    const it = uucode.grapheme.utf8Iterator("\u{1F1E6}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth emoji" {
    const it = uucode.grapheme.utf8Iterator("😀");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth ambiguous" {
    const it = uucode.grapheme.utf8Iterator("\u{00A1}");
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it));
}

test "wcwidth fullwidth" {
    const it = uucode.grapheme.utf8Iterator("\u{3000}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth soft hyphen" {
    const it = uucode.grapheme.utf8Iterator("\u{00AD}");
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it));
}

test "wcwidth sequence base + Mn" {
    const it = uucode.grapheme.utf8Iterator("A\u{0300}");
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it));
}

test "wcwidth sequence base + Mc" {
    const it = uucode.grapheme.utf8Iterator("\u{0905}\u{0903}"); // A + Visarga
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence emoji + modifier" {
    // Boy + Light Skin Tone
    const it = uucode.grapheme.utf8Iterator("\u{1F466}\u{1F3FB}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence emoji + VS16" {
    // ☁️ (Cloud + VS16)
    const it = uucode.grapheme.utf8Iterator("\u{2601}\u{FE0F}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence emoji + VS15" {
    // ☁︎ (Cloud + VS15)
    const it = uucode.grapheme.utf8Iterator("\u{2601}\u{FE0E}");
    try std.testing.expectEqual(@as(u2, 1), wcwidth(it));
}

test "wcwidth sequence keycap" {
    // 1️⃣
    const it = uucode.grapheme.utf8Iterator("1\u{FE0F}\u{20E3}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence regional indicator full" {
    // 🇺🇸
    const it = uucode.grapheme.utf8Iterator("\u{1F1FA}\u{1F1F8}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence emoji zwj" {
    // 👨‍🌾 (Farmer)
    const it = uucode.grapheme.utf8Iterator("\u{1F468}\u{200D}\u{1F33E}_");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence emoji zwj long" {
    // 👩‍👩‍👧‍👦 (family: woman, woman, girl, boy)
    const it = uucode.grapheme.utf8Iterator("\u{1F469}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}_");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth sequence emoji zwj long with emoji modifiers" {
    // 👨🏻‍❤️‍💋‍👨🏿 Kiss: man, man, light skin tone, dark skin tone
    const it = uucode.grapheme.utf8Iterator("\u{1F468}\u{1F3FB}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F48B}\u{200D}\u{1F468}\u{1F3FF}_");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidthAdvance iterator state" {
    const str = "A\u{0300}B";
    var it = uucode.grapheme.utf8Iterator(str);

    // First grapheme: A + Combining Grave
    const w1 = wcwidthAdvance(&it);
    try std.testing.expectEqual(@as(u2, 1), w1);
    try std.testing.expectEqual(3, it.i); // 'A' (1) + 0x0300 (2) = 3 bytes

    // Second grapheme: B
    const w2 = wcwidthAdvance(&it);
    try std.testing.expectEqual(@as(u2, 1), w2);
    try std.testing.expectEqual(4, it.i); // + 'B' (1) = 4 bytes

    try std.testing.expect(it.peekCodePoint() == null);
}

test "wcwidth Hangul L+V" {
    // ᄀ (U+1100) + ᅡ (U+1161)
    const it = uucode.grapheme.utf8Iterator("\u{1100}\u{1161}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth Hangul L+V+T" {
    // ᄀ (U+1100) + ᅡ (U+1161) + ᆨ (U+11A8)
    const it = uucode.grapheme.utf8Iterator("\u{1100}\u{1161}\u{11A8}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth Hangul L+L+V" {
    // ᄀ (U+1100) + ᄀ (U+1100) + ᅡ (U+1161)
    // This is an archaic/complex sequence. 2 + 2 + 0 = 4 -> 3.
    const it = uucode.grapheme.utf8Iterator("\u{1100}\u{1100}\u{1161}");
    try std.testing.expectEqual(@as(u2, 3), wcwidth(it));
}

test "wcwidth Hangul LV+T" {
    // 가 (U+AC00) + ᆨ (U+11A8)
    const it = uucode.grapheme.utf8Iterator("\u{AC00}\u{11A8}");
    try std.testing.expectEqual(@as(u2, 2), wcwidth(it));
}

test "wcwidth Devanagari with ZWJ" {
    const str = "क्‍ष";
    const it = uucode.grapheme.Iterator(uucode.utf8.Iterator).init(.init(str));
    try std.testing.expect(wcwidth(it) == 2);
}

test "wcwidth Devanagari 3 consonants" {
    // Ka + Virama + Ka + Virama + Ka
    // 1 + 0 + 1 + 0 + 1 = 3
    const it = uucode.grapheme.utf8Iterator("\u{0915}\u{094D}\u{0915}\u{094D}\u{0915}");
    try std.testing.expectEqual(@as(u2, 3), wcwidth(it));
}
