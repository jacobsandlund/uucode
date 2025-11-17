//! The `wcwidth` is a calculation of the expected width of a codepoint in
//! cells of a monospaced font. It is not part of the Unicode standard.
//!
//! See resources/wcwidth for other implementations.

const std = @import("std");
const config = @import("config.zig");

fn compute(
    allocator: std.mem.Allocator,
    cp: u21,
    data: anytype,
    backing: anytype,
    tracking: anytype,
) std.mem.Allocator.Error!void {
    _ = allocator;
    _ = backing;
    _ = tracking;
    const gc = data.general_category;
    const block = data.block;

    if (cp == 0) {
        data.wcwidth = 0;
    } else if (gc == .other_control) {
        data.wcwidth = -1;
    } else if (gc == .mark_nonspacing or gc == .mark_enclosing) {
        data.wcwidth = 0;
    } else if (cp == 0x00AD) { // Soft hyphen
        data.wcwidth = 1;
    } else if (cp == 0x2E3A) { // Two-em dash
        data.wcwidth = 2;
    } else if (cp == 0x2E3B) { // Three-em dash
        data.wcwidth = 3;
    } else if (gc == .other_format and block != .arabic and cp != 0x08E2) {
        // Format except Arabic (from Ziglyph).
        data.wcwidth = 0;
    } else if (block == .hangul_jamo and cp >= 0x1160) {
        // Note though that 0x1160 and up in hangul_jamo are
        // east_asian_width == .neutral
        data.wcwidth = 0;
    } else if (data.east_asian_width == .wide or data.east_asian_width == .fullwidth) {
        data.wcwidth = 2;
    } else if (data.grapheme_break == .regional_indicator) {
        data.wcwidth = 2;
    } else {
        data.wcwidth = 1;
    }
}

pub const wcwidth = config.Extension{
    .inputs = &.{
        "block",
        "east_asian_width",
        "general_category",
        "grapheme_break",
        "is_emoji_modifier",
    },
    .compute = &compute,
    .fields = &.{
        .{ .name = "wcwidth", .type = i3 },
    },
};
