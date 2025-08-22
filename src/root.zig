const std = @import("std");
const getpkg = @import("get.zig");
const config = @import("config.zig");
const types = @import("types.zig");
pub const ascii = @import("ascii.zig");
const grapheme_break = @import("grapheme_break.zig");
const testing = std.testing;

pub const get = getpkg.get;
pub const getX = getpkg.getX;
pub const TypeOf = getpkg.TypeOf;
pub const TypeOfX = getpkg.TypeOfX;
pub const getPacked = getpkg.getPacked;
pub const PackedTypeOf = getpkg.PackedTypeOf;

pub const max_code_point = config.max_code_point;
pub const code_point_range_end = config.code_point_range_end;

pub const GeneralCategory = types.GeneralCategory;
pub const BidiClass = types.BidiClass;
pub const DecompositionType = types.DecompositionType;
pub const NumericType = types.NumericType;
pub const IndicConjunctBreak = types.IndicConjunctBreak;
pub const EastAsianWidth = types.EastAsianWidth;
pub const OriginalGraphemeBreak = types.OriginalGraphemeBreak;
pub const GraphemeBreak = types.GraphemeBreak;
pub const zero_width_non_joiner = types.zero_width_non_joiner;
pub const zero_width_joiner = types.zero_width_joiner;
pub const SpecialCasingCondition = types.SpecialCasingCondition;
pub const Block = types.Block;

pub const computeGraphemeBreak = grapheme_break.computeGraphemeBreak;
pub const graphemeBreak = grapheme_break.graphemeBreak;
pub const precomputeGraphemeBreak = grapheme_break.precomputeGraphemeBreak;
pub const GraphemeBreakState = grapheme_break.GraphemeBreakState;

test {
    std.testing.refAllDeclsRecursive(@This());
}

test "name" {
    var buffer = [_]u8{0} ** 88;
    try testing.expect(std.mem.eql(u8, get(.name, 65).slice(&buffer), "LATIN CAPITAL LETTER A"));
}

test "is_alphabetic" {
    try testing.expect(get(.is_alphabetic, 65)); // 'A'
    try testing.expect(get(.is_alphabetic, 97)); // 'a'
    try testing.expect(!get(.is_alphabetic, 0));
}

test "case_folding_simple" {
    try testing.expectEqual(97, get(.case_folding_simple, 65)); // 'a'
    try testing.expectEqual(97, get(.case_folding_simple, 97)); // 'a'
}

test "simple_uppercase_mapping" {
    try testing.expectEqual(65, get(.simple_uppercase_mapping, 97)); // 'a'
    try testing.expectEqual(null, get(.simple_uppercase_mapping, 65)); // 'A'
}

test "generalCategory" {
    try testing.expect(get(.general_category, 65) == .letter_uppercase); // 'A'
}

test "getPacked" {
    const d0 = getPacked("0", 65);
    try testing.expect(d0.general_category == .letter_uppercase);
    try testing.expect(d0.case_folding_simple.optional(65).? == 97);

    const d1 = getPacked("checks", 65);
    try testing.expect(d1.is_alphabetic);
    try testing.expect(d1.is_uppercase);
    try testing.expect(!d1.is_lowercase);
}

test "get an extension field" {
    try testing.expectEqual(0, getX(.foo, 65));
    try testing.expectEqual(3, getX(.foo, 0));
}

test "special_casing_condition" {
    var buffer: [1]types.SpecialCasingCondition = undefined;
    const conditions1 = get(.special_casing_condition, 65).slice(&buffer); // 'A'
    try testing.expectEqual(0, conditions1.len);

    // Greek Capital Sigma (U+03A3) which has Final_Sigma condition
    const conditions = get(.special_casing_condition, 0x03A3).slice(&buffer);
    try testing.expectEqual(1, conditions.len);
    try testing.expectEqual(types.SpecialCasingCondition.final_sigma, conditions[0]);
}

test "special_lowercase_mapping" {
    var mapping_buffer: [2]u21 = undefined;

    // Greek Capital Sigma (U+03A3) which has Final_Sigma condition
    const mapping = get(.special_lowercase_mapping, 0x03A3).slice(&mapping_buffer, 0x03A3);
    try testing.expectEqual(1, mapping.len);
    try testing.expectEqual(0x03C2, mapping[0]); // Should map to Greek Small Letter Final Sigma
}
