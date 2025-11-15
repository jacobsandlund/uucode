const std = @import("std");
const uucode = @import("../root.zig");
const types_x = @import("types.x.zig");

// TODO: verify if this is reasonable, and see if this is the best API.
// This only takes the width of the first > 0 width code point, as the theory
// is that all these code points are combined into one grapheme cluster.
// However, if there is a zero width joiner, then consider the width to be 2
// (wide), since it's likely to be a wide grapheme cluster.
pub fn unverifiedWcwidth(const_it: anytype) i3 {
    var it = const_it;
    var width: i3 = 0;
    var prev_cp: u21 = 0;
    while (it.nextCodepoint()) |result| {
        if (result.codepoint == uucode.config.zero_width_joiner) {
            width = 2;
        } else if (result.codepoint == 0xFE0F) {
            // Emoji presentation selector. Only apply to emoji (TODO: use
            // emoji-variation-sequences.txt)
            if (uucode.get(.grapheme_break, prev_cp) == .extended_pictographic) {
                width = 2;
            }
        } else if (result.codepoint == 0xFE0E) {
            // Text presentation selector. Only apply to emoji (TODO: use
            // emoji-variation-sequences.txt)
            if (uucode.get(.grapheme_break, prev_cp) == .extended_pictographic) {
                width = 1;
            }
        } else if (result.codepoint == 0x20E3) {
            // Emoji keycap sequenece.
            if (prev_cp == 0xFE0F) { // Emoji presentation selector
                // TODO: check the previous previous codepoint, or even use
                // emoji-sequences.txt
                width = 2;
            }
        } else if (width <= 0) {
            width = uucode.get(.wcwidth, result.codepoint);
        }

        prev_cp = result.codepoint;
        if (result.is_break) break;
    }

    return width;
}

test "unverifiedWcwidth" {
    const str = "क्‍ष";
    const it = uucode.grapheme.Iterator(uucode.utf8.Iterator).init(.init(str));
    try std.testing.expect(unverifiedWcwidth(it) == 2);
}
