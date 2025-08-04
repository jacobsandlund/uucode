const std = @import("std");
const getpkg = @import("get.zig");
const types = @import("types.zig");
const testing = std.testing;

// Expose extension API as `uucode.x`
pub const x = @import("x");

pub const get = getpkg.get;
const tableFor = getpkg.tableFor;
const data = getpkg.data;

// UnicodeData fields

pub fn name(cp: u21, buffer_for_embedded: []u8) []const u8 {
    const table = comptime tableFor("name");
    const n = data(table, cp).name;
    return n.slice(buffer_for_embedded);
}

pub fn generalCategory(cp: u21) types.GeneralCategory {
    const table = comptime tableFor("general_category");
    return data(table, cp).general_category;
}

pub fn canonicalCombiningClass(cp: u21) u8 {
    const table = comptime tableFor("canonical_combining_class");
    return data(table, cp).canonical_combining_class;
}

pub fn bidiClass(cp: u21) types.BidiClass {
    const table = comptime tableFor("bidi_class");
    return data(table, cp).bidi_class;
}

pub fn decompositionType(cp: u21) types.DecompositionType {
    const table = comptime tableFor("decomposition_type");
    return data(table, cp).decomposition_type;
}

pub fn decompositionMapping(cp: u21, buffer_for_embedded: []u21) []const u21 {
    const table = comptime tableFor("decomposition_mapping");
    const dm = data(table, cp).decomposition_mapping;
    return dm.slice(buffer_for_embedded);
}

pub fn numericType(cp: u21) types.NumericType {
    const table = comptime tableFor("numeric_type");
    return data(table, cp).numeric_type;
}

pub fn numericValueDecimal(cp: u21) ?u4 {
    const table = comptime tableFor("numeric_value_decimal");
    return data(table, cp).numeric_value_decimal.optional();
}

pub fn numericValueDigit(cp: u21) ?u4 {
    const table = comptime tableFor("numeric_value_digit");
    return data(table, cp).numeric_value_digit.optional();
}

pub fn numericValueNumeric(cp: u21, buffer_for_embedded: []u8) []const u8 {
    const table = comptime tableFor("numeric_value_numeric");
    const nvn = data(table, cp).numeric_value_numeric;
    return nvn.slice(buffer_for_embedded);
}

pub fn isBidiMirrored(cp: u21) bool {
    const table = comptime tableFor("is_bidi_mirrored");
    return data(table, cp).is_bidi_mirrored;
}

pub fn unicode1Name(cp: u21, buffer_for_embedded: []u8) []const u8 {
    const table = comptime tableFor("unicode_1_name");
    const u1n = data(table, cp).unicode_1_name;
    return u1n.slice(buffer_for_embedded);
}

pub fn simpleUppercaseMapping(cp: u21) ?u21 {
    const table = comptime tableFor("simple_uppercase_mapping");
    return data(table, cp).simple_uppercase_mapping.optional();
}

pub fn simpleLowercaseMapping(cp: u21) ?u21 {
    const table = comptime tableFor("simple_lowercase_mapping");
    return data(table, cp).simple_lowercase_mapping.optional();
}

pub fn simpleTitlecaseMapping(cp: u21) ?u21 {
    const table = comptime tableFor("simple_titlecase_mapping");
    return data(table, cp).simple_titlecase_mapping.optional();
}

// CaseFolding fields

pub fn caseFoldingSimple(cp: u21) u21 {
    const table = comptime tableFor("case_folding_simple");
    const cf = data(table, cp).case_folding_simple;
    return cf.optional() orelse cp;
}

pub fn caseFoldingTurkish(cp: u21) ?u21 {
    const table = comptime tableFor("case_folding_turkish");
    return data(table, cp).case_folding_turkish.optional();
}

pub fn caseFoldingFull(cp: u21, buffer_for_embedded: []u21) []const u21 {
    const table = comptime tableFor("case_folding_full");
    const cff = data(table, cp).case_folding_full;
    return cff.slice(buffer_for_embedded);
}

// DerivedCoreProperties fields

pub fn isMath(cp: u21) bool {
    const table = comptime tableFor("is_math");
    return data(table, cp).is_math;
}

pub fn isAlphabetic(cp: u21) bool {
    const table = comptime tableFor("is_alphabetic");
    return data(table, cp).is_alphabetic;
}

pub fn isLowercase(cp: u21) bool {
    const table = comptime tableFor("is_lowercase");
    return data(table, cp).is_lowercase;
}

pub fn isUppercase(cp: u21) bool {
    const table = comptime tableFor("is_uppercase");
    return data(table, cp).is_uppercase;
}

pub fn isCased(cp: u21) bool {
    const table = comptime tableFor("is_cased");
    return data(table, cp).is_cased;
}

pub fn isCaseIgnorable(cp: u21) bool {
    const table = comptime tableFor("is_case_ignorable");
    return data(table, cp).is_case_ignorable;
}

pub fn changesWhenLowercased(cp: u21) bool {
    const table = comptime tableFor("changes_when_lowercased");
    return data(table, cp).changes_when_lowercased;
}

pub fn changesWhenUppercased(cp: u21) bool {
    const table = comptime tableFor("changes_when_uppercased");
    return data(table, cp).changes_when_uppercased;
}

pub fn changesWhenTitlecased(cp: u21) bool {
    const table = comptime tableFor("changes_when_titlecased");
    return data(table, cp).changes_when_titlecased;
}

pub fn changesWhenCasefolded(cp: u21) bool {
    const table = comptime tableFor("changes_when_casefolded");
    return data(table, cp).changes_when_casefolded;
}

pub fn changesWhenCasemapped(cp: u21) bool {
    const table = comptime tableFor("changes_when_casemapped");
    return data(table, cp).changes_when_casemapped;
}

pub fn isIdStart(cp: u21) bool {
    const table = comptime tableFor("is_id_start");
    return data(table, cp).is_id_start;
}

pub fn isIdContinue(cp: u21) bool {
    const table = comptime tableFor("is_id_continue");
    return data(table, cp).is_id_continue;
}

pub fn isXidStart(cp: u21) bool {
    const table = comptime tableFor("is_xid_start");
    return data(table, cp).is_xid_start;
}

pub fn isXidContinue(cp: u21) bool {
    const table = comptime tableFor("is_xid_continue");
    return data(table, cp).is_xid_continue;
}

pub fn isDefaultIgnorableCodePoint(cp: u21) bool {
    const table = comptime tableFor("is_default_ignorable_code_point");
    return data(table, cp).is_default_ignorable_code_point;
}

pub fn isGraphemeExtend(cp: u21) bool {
    const table = comptime tableFor("is_grapheme_extend");
    return data(table, cp).is_grapheme_extend;
}

pub fn isGraphemeBase(cp: u21) bool {
    const table = comptime tableFor("is_grapheme_base");
    return data(table, cp).is_grapheme_base;
}

pub fn isGraphemeLink(cp: u21) bool {
    const table = comptime tableFor("is_grapheme_link");
    return data(table, cp).is_grapheme_link;
}

pub fn indicConjunctBreak(cp: u21) types.IndicConjunctBreak {
    const table = comptime tableFor("indic_conjunct_break");
    return data(table, cp).indic_conjunct_break;
}

// EastAsianWidth field

pub fn eastAsianWidth(cp: u21) types.EastAsianWidth {
    const table = comptime tableFor("east_asian_width");
    return data(table, cp).east_asian_width;
}

// GraphemeBreak field

pub fn graphemeBreak(cp: u21) types.GraphemeBreak {
    const table = comptime tableFor("grapheme_break");
    return data(table, cp).grapheme_break;
}

// EmojiData fields

pub fn isEmoji(cp: u21) bool {
    const table = comptime tableFor("is_emoji");
    return data(table, cp).is_emoji;
}

pub fn hasEmojiPresentation(cp: u21) bool {
    const table = comptime tableFor("has_emoji_presentation");
    return data(table, cp).has_emoji_presentation;
}

pub fn isEmojiModifier(cp: u21) bool {
    const table = comptime tableFor("is_emoji_modifier");
    return data(table, cp).is_emoji_modifier;
}

pub fn isEmojiModifierBase(cp: u21) bool {
    const table = comptime tableFor("is_emoji_modifier_base");
    return data(table, cp).is_emoji_modifier_base;
}

pub fn isEmojiComponent(cp: u21) bool {
    const table = comptime tableFor("is_emoji_component");
    return data(table, cp).is_emoji_component;
}

pub fn isExtendedPictographic(cp: u21) bool {
    const table = comptime tableFor("is_extended_pictographic");
    return data(table, cp).is_extended_pictographic;
}

test {
    // TODO: "tables" will need to have data for every field
    //std.testing.refAllDecls(@This());
}

test "name" {
    var buffer = [_]u8{0} ** 88;
    try testing.expect(std.mem.eql(u8, name(65, &buffer), "LATIN CAPITAL LETTER A"));
}

test "isAlphabetic" {
    try testing.expect(isAlphabetic(65)); // 'A'
    try testing.expect(isAlphabetic(97)); // 'a'
    try testing.expect(!isAlphabetic(0));
}

test "caseFoldingSimple" {
    try testing.expectEqual(97, caseFoldingSimple(65)); // 'a'
    try testing.expectEqual(97, caseFoldingSimple(97)); // 'a'
}

// TODO: "tables" will need to have data for every field
//test "generalCategory" {
//    try testing.expect(generalCategory(65) == .Lu); // 'A'
//}

// TODO: figure out how to get the build to test get.zig, and move these there:

test "get" {
    const d1 = get("1", 65);
    try testing.expect(d1.is_alphabetic);
    try testing.expect(d1.is_uppercase);
    try testing.expect(!d1.is_lowercase);
}

test "get an extension field" {
    try testing.expectEqual(0, get("0", 65).foo);
    try testing.expectEqual(3, get("0", 0).foo);
}

test "uucode.x" {
    try testing.expectEqual(0, x.foo(65));
    try testing.expectEqual(3, x.foo(0));
}
