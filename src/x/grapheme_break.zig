const std = @import("std");
const uucode = @import("../root.zig");
const types_x = @import("types.x.zig");

fn mapXEmojiToOriginal(gbx: types_x.GraphemeBreakXEmoji) uucode.types.GraphemeBreak {
    return switch (gbx) {
        .emoji_modifier => .indic_conjunct_break_extend,
        .emoji_modifier_base => .extended_pictographic,

        inline else => |g| comptime blk: {
            @setEvalBranchQuota(10_000);
            break :blk std.meta.stringToEnum(
                uucode.types.GraphemeBreak,
                @tagName(g),
            ) orelse unreachable;
        },
    };
}

// Despite `emoji_modifier` being `extend`, UTS #51 states:
// `emoji_modifier_sequence := emoji_modifier_base emoji_modifier`
// and: "When used alone, the default representation of these modifier
// characters is a color swatch" See this revision of UAX #29 when the grapheme
// cluster break properties were simplified to remove `E_Base` and
// `E_Modifier`: http://www.unicode.org/reports/tr29/tr29-32.html
pub fn computeGraphemeBreakXEmoji(
    gbx1: types_x.GraphemeBreakXEmoji,
    gbx2: types_x.GraphemeBreakXEmoji,
    state: *uucode.grapheme_break.State,
) bool {
    const gb1 = mapXEmojiToOriginal(gbx1);
    const gb2 = mapXEmojiToOriginal(gbx2);
    const result = uucode.grapheme_break.computeGraphemeBreak(gb1, gb2, state);

    if (gbx2 == .emoji_modifier) {
        if (gbx1 == .emoji_modifier_base) {
            if (state.* != .extended_pictographic) {
                std.log.err("emoji_modifier_base must follow emoji_modifier, but state is {s}", .{
                    @tagName(state.*),
                });
            }
            std.debug.assert(state.* == .extended_pictographic);
            return false;
        } else {
            // Only break when `emoji_modifier` follows `emoji_modifier_base`.
            // Note also from UTS #51:
            // > Implementations may choose to support old data that contains
            // > defective emoji_modifier_sequences, that is, having emoji
            // > presentation selectors.
            // but here we don't support that.
            return true;
        }
    } else {
        return result;
    }
}

pub fn checkXEmoji(
    cp1: u21,
    cp2: u21,
    state: *uucode.grapheme_break.State,
) bool {
    const table = comptime uucode.grapheme_break.precomputeGraphemeBreak(
        types_x.GraphemeBreakXEmoji,
        computeGraphemeBreakXEmoji,
    );
    const gb1 = uucode.get(.grapheme_break_x_emoji, cp1);
    const gb2 = uucode.get(.grapheme_break_x_emoji, cp2);
    const result = table.get(gb1, gb2, state.*);
    state.* = result.state;
    return result.result;
}
