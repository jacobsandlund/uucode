const std = @import("std");
const uucode = @import("../root.zig");
const types_x = @import("types.x.zig");

// TODO: verify if this is reasonable, and see if this is the best API.
// This only takes the width of the first > 0 width code point, as the theory
// is that all these code points are combined into one grapheme cluster.
// However, if there is a zero width joiner, then consider the width to be 2
// (wide), since it's likely to be a wide grapheme cluster.

// See src/x/config_x/wcwidth.zig for the logic determining the width of a
// single code point standing alone.
//
// This implementation makes the following choices (TODO):
//
// * Note: Per UAX #44, nonspacing marks (Mn) have "zero advance width" while
//   spacing marks (Mc) have "positive advance width"
//   (https://www.unicode.org/reports/tr44/#General_Category_Values).
//   Enclosing marks (Me) are not explicitly specified, but in terminal
//   rendering contexts they behave similarly to nonspacing marks—they don't
//   add horizontal spacing. See also Core Spec 2.11, "Nonspacing combining
//   characters do not occupy a spacing position by themselves"
//   (https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-2/#G1789).
//
pub fn unverifiedWcwidth(const_it: anytype) i3 {
    var it = const_it;
    var width: i3 = 0;
    var prev_cp: u21 = 0;
    while (it.nextCodePoint()) |result| {
        if (result.code_point == uucode.config.zero_width_joiner) {
            width = 2;
        } else if (result.code_point == 0xFE0F) {
            // Emoji presentation selector. Only apply to emoji (TODO: use
            // emoji-variation-sequences.txt)
            if (uucode.get(.grapheme_break, prev_cp) == .extended_pictographic) {
                width = 2;
            }
        } else if (result.code_point == 0xFE0E) {
            // Text presentation selector. Only apply to emoji (TODO: use
            // emoji-variation-sequences.txt)
            if (uucode.get(.grapheme_break, prev_cp) == .extended_pictographic) {
                width = 1;
            }
        } else if (result.code_point == 0x20E3) {
            // Emoji keycap sequenece.
            if (prev_cp == 0xFE0F) { // Emoji presentation selector
                // TODO: check the previous previous code point, or even use
                // emoji-sequences.txt
                width = 2;
            }
        } else if (width <= 0) {
            width = uucode.get(.wcwidth, result.code_point);
        }

        prev_cp = result.code_point;
        if (result.is_break) break;
    }

    return width;
}

test "unverifiedWcwidth" {
    const str = "क्‍ष";
    const it = uucode.grapheme.Iterator(uucode.utf8.Iterator).init(.init(str));
    try std.testing.expect(unverifiedWcwidth(it) == 2);
}
