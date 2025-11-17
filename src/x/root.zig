const std = @import("std");
pub const types_x = @import("types.x.zig");
pub const grapheme = @import("grapheme.zig");
const testing = std.testing;

// wcwidth tests

test "wcwidth emoji_modifier is 2" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x1F3FF)); // 🏿
}

test "wcwidth control characters are width 0" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x0000)); // NULL (C0)
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x001F)); // UNIT SEPARATOR (C0)
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x007F)); // DELETE (C0)
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x0080)); // C1 control
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x009F)); // C1 control
}

test "wcwidth surrogates are width 0" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xD800)); // High surrogate start
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xDBFF)); // High surrogate end
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xDC00)); // Low surrogate start
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xDFFF)); // Low surrogate end
}

test "wcwidth line and paragraph separators are width 0" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x2028)); // LINE SEPARATOR (Zl)
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x2029)); // PARAGRAPH SEPARATOR (Zp)
}

test "wcwidth default ignorable characters are width 0" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x200B)); // ZERO WIDTH SPACE
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x200C)); // ZERO WIDTH NON-JOINER (ZWNJ)
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0x200D)); // ZERO WIDTH JOINER (ZWJ)
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xFE00)); // VARIATION SELECTOR-1
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xFE0F)); // VARIATION SELECTOR-16
    try testing.expectEqual(@as(i3, 0), get(.wcwidth, 0xFEFF)); // ZERO WIDTH NO-BREAK SPACE
}

test "wcwidth soft hyphen exception is width 1" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x00AD)); // SOFT HYPHEN
}

test "wcwidth combining marks are width 1" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x0300)); // COMBINING GRAVE ACCENT (Mn)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x0903)); // DEVANAGARI SIGN VISARGA (Mc)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x20DD)); // COMBINING ENCLOSING CIRCLE (Me)
}

test "wcwidth combining enclosing keycap exception is width 2" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x20E3)); // COMBINING ENCLOSING KEYCAP
}

test "wcwidth regional indicators are width 2" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x1F1E6)); // Regional Indicator A
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x1F1FA)); // Regional Indicator U
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x1F1F8)); // Regional Indicator S
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x1F1FF)); // Regional Indicator Z
}

test "wcwidth em dashes have special widths" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x2E3A)); // TWO-EM DASH
    try testing.expectEqual(@as(i3, 3), get(.wcwidth, 0x2E3B)); // THREE-EM DASH
}

test "wcwidth ambiguous width characters are width 1" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x00A1)); // INVERTED EXCLAMATION MARK (A)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x00B1)); // PLUS-MINUS SIGN (A)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x2664)); // WHITE SPADE SUIT (A)
}

test "wcwidth east asian wide and fullwidth are width 2" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x3000)); // IDEOGRAPHIC SPACE (F)
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0xFF01)); // FULLWIDTH EXCLAMATION MARK (F)
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0x4E00)); // CJK UNIFIED IDEOGRAPH (W)
    try testing.expectEqual(@as(i3, 2), get(.wcwidth, 0xAC00)); // HANGUL SYLLABLE (W)
}

test "wcwidth hangul jamo V and T are width 1" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x1161)); // HANGUL JUNGSEONG A (V)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x11A8)); // HANGUL JONGSEONG KIYEOK (T)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0xD7B0)); // HANGUL JUNGSEONG O-YEO (V)
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0xD7CB)); // HANGUL JONGSEONG NIEUN-RIEUL (T)
}

test "wcwidth format characters non-DI are width 1" {
    const get = @import("get.zig").get;
    try testing.expectEqual(@as(i3, 1), get(.wcwidth, 0x0600)); // ARABIC NUMBER SIGN (Cf, not DI)
}
