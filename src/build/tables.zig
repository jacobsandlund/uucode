const std = @import("std");
const Ucd = @import("Ucd.zig");
const data = @import("../data.zig");

pub fn write(allocator: std.mem.Allocator, writer: anytype) !void {
    var ucd = try Ucd.init(allocator);
    defer ucd.deinit(allocator);

    try writer.print(
        \\//! This file is auto-generated. Do not edit.
        \\
        \\const data = @import("data");
        \\pub const table: [{}]u21 = .{{
        \\
    ,
        .{data.num_code_points},
    );

    var cp: u21 = data.min_code_point;
    while (cp < data.code_point_range_end) : (cp += 1) {
        //const unicode_data = ucd.unicode_data[cp - data.min_code_point];
        const case_folding = ucd.case_folding.get(cp) orelse data.CaseFolding{};
        //const derived_core_properties = ucd.derived_core_properties.get(cp) orelse data.DerivedCoreProperties{};
        //const east_asian_width = ucd.east_asian_width.get(cp) orelse data.EastAsianWidth.neutral;
        //const grapheme_break = ucd.grapheme_break.get(cp) orelse data.GraphemeBreak.other;
        //const emoji_data = ucd.emoji_data.get(cp) orelse data.EmojiData{};

        //try writer.print(
        //    \\    .{{
        //    \\        .unicode_data = .{{
        //    \\            .name = "{s}",
        //    \\            .general_category = .{s},
        //    \\            .canonical_combining_class = {},
        //    \\            .bidi_class = .{s},
        //    \\            .decomposition_type = "{s}",
        //    \\            .decomposition_mapping = "{s}",
        //    \\            .numeric_type = "{s}",
        //    \\            .numeric_value = "{s}",
        //    \\            .numeric_digit = "{s}",
        //    \\            .bidi_mirrored = {},
        //    \\            .unicode_1_name = "{s}",
        //    \\            .iso_comment = "{s}",
        //    \\            .simple_uppercase_mapping = {?},
        //    \\            .simple_lowercase_mapping = {?},
        //    \\            .simple_titlecase_mapping = {?},
        //    \\        }},
        //    \\
        //,
        //    .{
        //        unicode_data.name,
        //        @tagName(unicode_data.general_category),
        //        unicode_data.canonical_combining_class,
        //        @tagName(unicode_data.bidi_class),
        //        unicode_data.decomposition_type,
        //        unicode_data.decomposition_mapping,
        //        unicode_data.numeric_type,
        //        unicode_data.numeric_value,
        //        unicode_data.numeric_digit,
        //        unicode_data.bidi_mirrored,
        //        unicode_data.unicode_1_name,
        //        unicode_data.iso_comment,
        //        unicode_data.simple_uppercase_mapping,
        //        unicode_data.simple_lowercase_mapping,
        //        unicode_data.simple_titlecase_mapping,
        //    },
        //);

        //try writer.print(
        //    \\        .case_folding = .{{
        //    \\            .simple = {},
        //    \\            .turkish = {?},
        //    \\            .full = .{{ {}, {}, {} }},
        //    \\            .full_len = {},
        //    \\        }},
        //    \\
        //,
        //    .{
        //        case_folding.simple,
        //        case_folding.turkish,
        //        case_folding.full[0],
        //        case_folding.full[1],
        //        case_folding.full[2],
        //        case_folding.full_len,
        //    },
        //);
        try writer.print("{},", .{case_folding.simple});

        //try writer.print(
        //    \\        .derived_core_properties = .{{
        //    \\            .math = {},
        //    \\            .alphabetic = {},
        //    \\            .lowercase = {},
        //    \\            .uppercase = {},
        //    \\            .cased = {},
        //    \\            .case_ignorable = {},
        //    \\            .changes_when_lowercased = {},
        //    \\            .changes_when_uppercased = {},
        //    \\            .changes_when_titlecased = {},
        //    \\            .changes_when_casefolded = {},
        //    \\            .changes_when_casemapped = {},
        //    \\            .id_start = {},
        //    \\            .id_continue = {},
        //    \\            .xid_start = {},
        //    \\            .xid_continue = {},
        //    \\            .default_ignorable_code_point = {},
        //    \\            .grapheme_extend = {},
        //    \\            .grapheme_base = {},
        //    \\            .grapheme_link = {},
        //    \\            .incb = {},
        //    \\        }},
        //    \\
        //,
        //    .{
        //        derived_core_properties.math,
        //        derived_core_properties.alphabetic,
        //        derived_core_properties.lowercase,
        //        derived_core_properties.uppercase,
        //        derived_core_properties.cased,
        //        derived_core_properties.case_ignorable,
        //        derived_core_properties.changes_when_lowercased,
        //        derived_core_properties.changes_when_uppercased,
        //        derived_core_properties.changes_when_titlecased,
        //        derived_core_properties.changes_when_casefolded,
        //        derived_core_properties.changes_when_casemapped,
        //        derived_core_properties.id_start,
        //        derived_core_properties.id_continue,
        //        derived_core_properties.xid_start,
        //        derived_core_properties.xid_continue,
        //        derived_core_properties.default_ignorable_code_point,
        //        derived_core_properties.grapheme_extend,
        //        derived_core_properties.grapheme_base,
        //        derived_core_properties.grapheme_link,
        //        derived_core_properties.incb,
        //    },
        //);

        //try writer.print(
        //    \\        .east_asian_width = .{s},
        //    \\        .grapheme_break = .{s},
        //    \\        .emoji_data = .{{
        //    \\            .emoji = {},
        //    \\            .emoji_presentation = {},
        //    \\            .emoji_modifier = {},
        //    \\            .emoji_modifier_base = {},
        //    \\            .emoji_component = {},
        //    \\            .extended_pictographic = {},
        //    \\        }},
        //    \\    }},
        //    \\
        //,
        //    .{
        //        @tagName(east_asian_width),
        //        @tagName(grapheme_break),
        //        emoji_data.emoji,
        //        emoji_data.emoji_presentation,
        //        emoji_data.emoji_modifier,
        //        emoji_data.emoji_modifier_base,
        //        emoji_data.emoji_component,
        //        emoji_data.extended_pictographic,
        //    },
        //);
    }

    try writer.writeAll(
        \\};
        \\
    );
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
    @import("std").testing.refAllDeclsRecursive(Ucd);
}
