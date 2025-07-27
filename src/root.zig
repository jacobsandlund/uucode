const std = @import("std");
const testing = std.testing;
const tables = @import("table_data").tables;
const types = @import("types.zig");

fn DataFor(comptime table: anytype) type {
    const DataArray = @FieldType(@TypeOf(table), "data");
    return @typeInfo(DataArray).array.child;
}

fn TableDataFor(comptime field: []const u8) type {
    for (tables) |table| {
        if (@hasField(DataFor(table), field)) {
            return @TypeOf(table);
        }
    }
    @compileError("Table not found for field: " ++ field);
}

fn tableFor(comptime field: []const u8) TableDataFor(field) {
    inline for (tables) |table| {
        if (@hasField(DataFor(table), field)) {
            return table;
        }
    }
    unreachable;
}

// TODO: benchmark if needing an explicit `inline`
// TODO: support two stage (stage1 and data) tables
fn getData(comptime table: anytype, cp: u21) DataFor(table) {
    const stage1_idx = cp >> 8;
    const stage2_idx = cp & 0xFF;
    const block_start = @as(usize, table.stage1[stage1_idx]) << 8;
    const data_idx = table.stage2[block_start + stage2_idx];
    return table.data[data_idx];
}

pub fn data(comptime table_index: []const u8, cp: u21) DataFor(@field(tables, table_index)) {
    const table = @field(tables, table_index);
    return getData(table, cp);
}

// UnicodeData fields
pub fn name(cp: u21, buffer_for_embedded: []u8) []const u8 {
    const table = comptime tableFor("name");
    const n = getData(table, cp).name;
    return n.toSlice(&table.backing.name, buffer_for_embedded);
}

pub fn generalCategory(cp: u21) types.GeneralCategory {
    const table = comptime tableFor("general_category");
    return getData(table, cp).general_category;
}

pub fn canonicalCombiningClass(cp: u21) u8 {
    const table = comptime tableFor("canonical_combining_class");
    return getData(table, cp).canonical_combining_class;
}

pub fn bidiClass(cp: u21) types.BidiClass {
    const table = comptime tableFor("bidi_class");
    return getData(table, cp).bidi_class;
}

pub fn decompositionType(cp: u21) types.DecompositionType {
    const table = comptime tableFor("decomposition_type");
    return getData(table, cp).decomposition_type;
}

pub fn decompositionMapping(cp: u21, buffer_for_embedded: []u21) []const u21 {
    const table = comptime tableFor("decomposition_mapping");
    const dm = getData(table, cp).decomposition_mapping;
    return dm.toSlice(&table.backing.decomposition_mapping, buffer_for_embedded);
}

pub fn numericType(cp: u21) types.NumericType {
    const table = comptime tableFor("numeric_type");
    return getData(table, cp).numeric_type;
}

pub fn numericValueDecimal(cp: u21) ?u4 {
    const table = comptime tableFor("numeric_value_decimal");
    return getData(table, cp).numeric_value_decimal.toOptional();
}

pub fn numericValueDigit(cp: u21) ?u4 {
    const table = comptime tableFor("numeric_value_digit");
    return getData(table, cp).numeric_value_digit.toOptional();
}

pub fn numericValueNumeric(cp: u21, buffer_for_embedded: []u8) []const u8 {
    const table = comptime tableFor("numeric_value_numeric");
    const nvn = getData(table, cp).numeric_value_numeric;
    return nvn.toSlice(&table.backing.numeric_value_numeric, buffer_for_embedded);
}

pub fn isBidiMirrored(cp: u21) bool {
    const table = comptime tableFor("is_bidi_mirrored");
    return getData(table, cp).is_bidi_mirrored;
}

pub fn unicode1Name(cp: u21, buffer_for_embedded: []u8) []const u8 {
    const table = comptime tableFor("unicode_1_name");
    const u1n = getData(table, cp).unicode_1_name;
    return u1n.toSlice(&table.backing.unicode_1_name, buffer_for_embedded);
}

pub fn simpleUppercaseMapping(cp: u21) ?u21 {
    const table = comptime tableFor("simple_uppercase_mapping");
    return getData(table, cp).simple_uppercase_mapping.toOptional();
}

pub fn simpleLowercaseMapping(cp: u21) ?u21 {
    const table = comptime tableFor("simple_lowercase_mapping");
    return getData(table, cp).simple_lowercase_mapping.toOptional();
}

pub fn simpleTitlecaseMapping(cp: u21) ?u21 {
    const table = comptime tableFor("simple_titlecase_mapping");
    return getData(table, cp).simple_titlecase_mapping.toOptional();
}

// CaseFolding fields
pub fn caseFoldingSimple(cp: u21) u21 {
    const table = comptime tableFor("case_folding_simple");
    return getData(table, cp).case_folding_simple.toOptional() orelse cp;
}

pub fn caseFoldingTurkish(cp: u21) ?u21 {
    const table = comptime tableFor("case_folding_turkish");
    return getData(table, cp).case_folding_turkish.toOptional();
}

pub fn caseFoldingFull(cp: u21, buffer_for_embedded: []u21) []const u21 {
    const table = comptime tableFor("case_folding_full");
    const cff = getData(table, cp).case_folding_full;
    return cff.toSlice(&table.backing.case_folding_full, buffer_for_embedded);
}

// DerivedCoreProperties fields
pub fn isMath(cp: u21) bool {
    const table = comptime tableFor("is_math");
    return getData(table, cp).is_math;
}

pub fn isAlphabetic(cp: u21) bool {
    const table = comptime tableFor("is_alphabetic");
    return getData(table, cp).is_alphabetic;
}

pub fn isLowercase(cp: u21) bool {
    const table = comptime tableFor("is_lowercase");
    return getData(table, cp).is_lowercase;
}

pub fn isUppercase(cp: u21) bool {
    const table = comptime tableFor("is_uppercase");
    return getData(table, cp).is_uppercase;
}

pub fn isCased(cp: u21) bool {
    const table = comptime tableFor("is_cased");
    return getData(table, cp).is_cased;
}

pub fn isCaseIgnorable(cp: u21) bool {
    const table = comptime tableFor("is_case_ignorable");
    return getData(table, cp).is_case_ignorable;
}

pub fn changesWhenLowercased(cp: u21) bool {
    const table = comptime tableFor("changes_when_lowercased");
    return getData(table, cp).changes_when_lowercased;
}

pub fn changesWhenUppercased(cp: u21) bool {
    const table = comptime tableFor("changes_when_uppercased");
    return getData(table, cp).changes_when_uppercased;
}

pub fn changesWhenTitlecased(cp: u21) bool {
    const table = comptime tableFor("changes_when_titlecased");
    return getData(table, cp).changes_when_titlecased;
}

pub fn changesWhenCasefolded(cp: u21) bool {
    const table = comptime tableFor("changes_when_casefolded");
    return getData(table, cp).changes_when_casefolded;
}

pub fn changesWhenCasemapped(cp: u21) bool {
    const table = comptime tableFor("changes_when_casemapped");
    return getData(table, cp).changes_when_casemapped;
}

pub fn isIdStart(cp: u21) bool {
    const table = comptime tableFor("is_id_start");
    return getData(table, cp).is_id_start;
}

pub fn isIdContinue(cp: u21) bool {
    const table = comptime tableFor("is_id_continue");
    return getData(table, cp).is_id_continue;
}

pub fn isXidStart(cp: u21) bool {
    const table = comptime tableFor("is_xid_start");
    return getData(table, cp).is_xid_start;
}

pub fn isXidContinue(cp: u21) bool {
    const table = comptime tableFor("is_xid_continue");
    return getData(table, cp).is_xid_continue;
}

pub fn isDefaultIgnorableCodePoint(cp: u21) bool {
    const table = comptime tableFor("is_default_ignorable_code_point");
    return getData(table, cp).is_default_ignorable_code_point;
}

pub fn isGraphemeExtend(cp: u21) bool {
    const table = comptime tableFor("is_grapheme_extend");
    return getData(table, cp).is_grapheme_extend;
}

pub fn isGraphemeBase(cp: u21) bool {
    const table = comptime tableFor("is_grapheme_base");
    return getData(table, cp).is_grapheme_base;
}

pub fn isGraphemeLink(cp: u21) bool {
    const table = comptime tableFor("is_grapheme_link");
    return getData(table, cp).is_grapheme_link;
}

pub fn indicConjunctBreak(cp: u21) types.IndicConjunctBreak {
    const table = comptime tableFor("indic_conjunct_break");
    return getData(table, cp).indic_conjunct_break;
}

// EastAsianWidth field
pub fn eastAsianWidth(cp: u21) types.EastAsianWidth {
    const table = comptime tableFor("east_asian_width");
    return getData(table, cp).east_asian_width;
}

// GraphemeBreak field
pub fn graphemeBreak(cp: u21) types.GraphemeBreak {
    const table = comptime tableFor("grapheme_break");
    return getData(table, cp).grapheme_break;
}

// EmojiData fields
pub fn isEmoji(cp: u21) bool {
    const table = comptime tableFor("is_emoji");
    return getData(table, cp).is_emoji;
}

pub fn hasEmojiPresentation(cp: u21) bool {
    const table = comptime tableFor("has_emoji_presentation");
    return getData(table, cp).has_emoji_presentation;
}

pub fn isEmojiModifier(cp: u21) bool {
    const table = comptime tableFor("is_emoji_modifier");
    return getData(table, cp).is_emoji_modifier;
}

pub fn isEmojiModifierBase(cp: u21) bool {
    const table = comptime tableFor("is_emoji_modifier_base");
    return getData(table, cp).is_emoji_modifier_base;
}

pub fn isEmojiComponent(cp: u21) bool {
    const table = comptime tableFor("is_emoji_component");
    return getData(table, cp).is_emoji_component;
}

pub fn isExtendedPictographic(cp: u21) bool {
    const table = comptime tableFor("is_extended_pictographic");
    return getData(table, cp).is_extended_pictographic;
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
    try testing.expectEqual(caseFoldingSimple(65), 97); // 'a'
    try testing.expectEqual(caseFoldingSimple(97), 97); // 'a'
}

// TODO: "tables" will need to have data for every field
//test "generalCategory" {
//    try testing.expect(generalCategory(65) == .Lu); // 'A'
//}
