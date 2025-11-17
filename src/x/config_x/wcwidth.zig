//! The `wcwidth` is a calculation of the expected width of a codepoint in
//! cells of a monospaced font. It is not part of the Unicode standard.
//!
//! See resources/wcwidth for other implementations, that help to inform the
//! implementation here.
//!
//! This implementation makes the following choices:
//!
//! * This wcwidth computes the width for a codepoint as it would display
//!   **standing alone** without being combined with other codepoints in a
//!   grapheme cluster. See `src/x/grapheme.zig` for the code to determine the
//!   width of a grapheme cluster that may contain multiple code points.
//!
//! * The returned width is never negative. C0 and C1 control characters are
//!   treated as zero width, diverging from some implementations that return
//!   -1.
//!
//! * When a combining mark (Mn, Mc, Me) stands alone (not preceded by a base
//!   character), it forms a "defective combining character sequence" (Core Spec
//!   3.6,
//!   https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/#G20665).
//!   Per Core Spec 5.13: "Defective combining character sequences should be
//!   rendered as if they had a no-break space as a base character"
//!   (https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-5/#G1099).
//!
//! * East Asian Width (UAX #11, https://www.unicode.org/reports/tr11/) is used
//!   to determine width, but only as a starting point. UAX #11 warns that
//!   East_Asian_Width "is not intended for use by modern terminal emulators
//!   without appropriate tailoring" (UAX #11 §2,
//!   https://www.unicode.org/reports/tr11/#Scope). This implementation applies
//!   tailoring for specific cases such as regional indicators.
//!
//!   Ambiguous width (A) characters are treated as width 1. Per UAX #11 §5
//!   Recommendations: "If the context cannot be established reliably, they
//!   should be treated as narrow characters by default"
//!   (https://www.unicode.org/reports/tr11/#Recommendations), and per UAX #11
//!   §4.2 Ambiguous Characters: "Modern practice is evolving toward rendering
//!   ever more of the ambiguous characters with proportionally spaced, narrow
//!   forms that rotate with the direction of writing, independent of their
//!   treatment in one or more legacy character sets."
//!
//! * U+20E3 COMBINING ENCLOSING KEYCAP is treated as width 2 despite being an
//!   enclosing mark (Me). When standing alone, it renders as an empty keycap
//!   symbol which is emoji-like and visually occupies 2 cells. This is a
//!   special case—other enclosing marks like U+20DD COMBINING ENCLOSING CIRCLE
//!   are width 1. U+20E3 is commonly used in emoji keycap sequences like 1️⃣
//!   (digit + VS16 + U+20E3).
//!
//! * Regional indicator symbols (U+1F1E6..U+1F1FF) are treated as width 2,
//!   whether paired in valid emoji flag sequences or standing alone. Per UTS #51
//!   §1.5 Conformance: "A singleton emoji Regional Indicator may be displayed
//!   as a capital A..Z character with a special display"
//!   (https://www.unicode.org/reports/tr51/#C3). Unpaired regional indicators
//!   commonly render as the corresponding letter in a width-2 box (e.g., 🇺
//!   displays as "U" in a box).
//!
//! * Default_Ignorable_Code_Point characters are treated as width 0. These are
//!   characters that "should be ignored in rendering (unless explicitly
//!   supported)" (UAX #44,
//!   https://www.unicode.org/reports/tr44/#Default_Ignorable_Code_Point). This
//!   includes variation selectors, join controls (ZWJ/ZWNJ), bidi formatting
//!   controls, tag characters, and other invisible format controls.
//!
//!   Exception: U+00AD SOFT HYPHEN is treated as width 1 for terminal
//!   compatibility despite being default-ignorable. Per the Unicode FAQ: "In a
//!   terminal emulation environment, particularly in ISO-8859-1 contexts, one
//!   could display the SOFT HYPHEN as a hyphen in all circumstances"
//!   (https://www.unicode.org/faq/casemap_charprop.html). Terminals lack
//!   sophisticated word-breaking algorithms and typically display SOFT HYPHEN as
//!   a visible hyphen, requiring width 1. This matches ecosystem wcwidth
//!   implementations.
//!
//! * Hangul Jamo medial vowels (Grapheme_Cluster_Break=V) and final consonants
//!   (Grapheme_Cluster_Break=T) are width 1 since they are
//!   General_Category=Other_Letter with East_Asian_Width=Neutral, unlike other
//!   wcwidth implementations which give them a width of 0 so that their
//!   incorrect grapheme width algorithm that sums all the code points in the
//!   cluster can add up the L+V+T of these decomposed Hangul sequences to get
//!   the correct final width.
//!
//! * Surrogates (General_Category=Cs, U+D800..U+DFFF) are treated as width 0.
//!   They are not Unicode scalar values (Core Spec 3.9,
//!   https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/#G25539)
//!   and "are designated for surrogate code units in the UTF-16 character
//!   encoding form. They are unassigned to any abstract character." (Core Spec
//!   3.2.1 C1,
//!   https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/#G22599).
//!
//! * U+2028 LINE SEPARATOR (Zl) and U+2029 PARAGRAPH SEPARATOR (Zp) are
//!   treated as width 0. They introduce mandatory line/paragraph breaks (UAX
//!   #14, Line_Break=BK, https://www.unicode.org/reports/tr14/#BK) and do not
//!   advance horizontally on the same line.
//!

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

    if (gc == .other_control or
        gc == .other_surrogate or
        gc == .separator_line or
        gc == .separator_paragraph)
    {
        data.wcwidth = 0;
    } else if (cp == 0x00AD) { // Soft hyphen
        data.wcwidth = 1;
    } else if (data.is_default_ignorable) {
        data.wcwidth = 0;
    } else if (cp == 0x20E3) { // Combining enclosing keycap
        data.wcwidth = 2;
    } else if (cp == 0x2E3A) { // Two-em dash
        data.wcwidth = 2;
    } else if (cp == 0x2E3B) { // Three-em dash
        data.wcwidth = 3;
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
        "east_asian_width",
        "general_category",
        "grapheme_break",
        "is_default_ignorable",
    },
    .compute = &compute,
    .fields = &.{
        .{ .name = "wcwidth", .type = u2 },
    },
};
