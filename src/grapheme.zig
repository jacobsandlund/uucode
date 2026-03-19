const std = @import("std");

const types = @import("types.zig");
const getpkg = @import("get.zig");
const utf8 = @import("utf8.zig");
const inlineAssert = @import("config.zig").quirks.inlineAssert;
const get = getpkg.get;
const FieldEnum = getpkg.FieldEnum;

pub const IteratorResult = struct {
    code_point: u21,
    is_break: bool,
};

pub const Grapheme = struct {
    start: usize,
    end: usize,
};

pub fn CustomIterator(
    comptime CodePointIterator: type,
    comptime GB: type,
    comptime State: type,
    comptime grapheme_break_field: FieldEnum,
    comptime customIsBreak: fn (gb1: GB, gb2: GB, state: *State) bool,
) type {
    return struct {
        // This "i" is part of the documented API of this iterator, pointing to
        // the current location of the iterator in the underlying bytes (the
        // `i` of the CodePointIterator).
        i: usize,

        state: State,
        next_cp_it: CodePointIterator,
        next_cp: ?u21,
        next_gb: GB,

        const Self = @This();

        pub fn init(cp_it: CodePointIterator) Self {
            var next_cp_it = cp_it;
            const i = next_cp_it.i;
            const next_cp = next_cp_it.next();

            return .{
                .state = .default,
                .i = i,
                .next_cp_it = next_cp_it,
                .next_cp = next_cp,
                .next_gb = if (next_cp) |code_point|
                    get(grapheme_break_field, code_point)
                else
                    .other,
            };
        }

        pub fn nextCodePoint(self: *Self) ?IteratorResult {
            if (self.next_cp == null) return null;

            const cp1 = self.next_cp.?;
            const gb1 = self.next_gb;
            self.i = self.next_cp_it.i;
            self.next_cp = self.next_cp_it.next();

            if (self.next_cp) |cp2| {
                self.next_gb = get(grapheme_break_field, cp2);
                const is_break = customIsBreak(gb1, self.next_gb, &self.state);
                return IteratorResult{
                    .code_point = cp1,
                    .is_break = is_break,
                };
            } else {
                return IteratorResult{
                    .code_point = cp1,
                    .is_break = true,
                };
            }
        }

        pub fn peekCodePoint(self: Self) ?IteratorResult {
            var it = self;
            return it.nextCodePoint();
        }

        pub fn nextGrapheme(self: *Self) ?Grapheme {
            const start = self.i;
            return while (self.nextCodePoint()) |result| {
                if (result.is_break) break .{ .start = start, .end = self.i };
            } else null;
        }

        pub fn peekGrapheme(self: Self) ?Grapheme {
            var it = self;
            return it.nextGrapheme();
        }
    };
}

pub fn Iterator(comptime CodePointIterator: type) type {
    return CustomIterator(
        CodePointIterator,
        types.GraphemeBreak,
        BreakState,
        .grapheme_break,
        precomputedGraphemeBreak,
    );
}

pub fn utf8Iterator(bytes: []const u8) Iterator(utf8.Iterator) {
    return Iterator(utf8.Iterator).init(.init(bytes));
}

test "Iterator nextCodePoint/peekCodePoint" {
    const str = "👩🏽‍🚀🇨🇭";
    var it = Iterator(utf8.Iterator).init(.init(str));
    try std.testing.expect(it.i == 0);

    var result = it.peekCodePoint();
    try std.testing.expect(it.i == 0);
    try std.testing.expect(result.?.code_point == 0x1F469); // 👩
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(it.i == 4);
    try std.testing.expect(result.?.code_point == 0x1F469); // 👩
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F3FD); // 🏽
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D); // Zero width joiner
    try std.testing.expect(result.?.is_break == false);

    result = it.peekCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F680); // 🚀
    try std.testing.expect(result.?.is_break == true);

    result = it.nextCodePoint();
    try std.testing.expect(it.i == 15);
    try std.testing.expect(result.?.code_point == 0x1F680); // 🚀
    try std.testing.expect(result.?.is_break == true);
    try std.testing.expect(std.mem.eql(u8, str[0..it.i], "👩🏽‍🚀"));

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1E8); // Regional Indicator "C"
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(it.i == str.len);
    try std.testing.expect(result.?.code_point == 0x1F1ED); // Regional Indicator "H"
    try std.testing.expect(result.?.is_break == true);

    try std.testing.expect(it.peekCodePoint() == null);
    try std.testing.expect(it.nextCodePoint() == null);
    try std.testing.expect(it.nextCodePoint() == null);
}

test "utf8Iterator nextGrapheme/peekGrapheme" {
    const str = "👩🏽‍🚀🇨🇭👨🏻‍🍼";
    var it = utf8Iterator(str);
    try std.testing.expect(it.i == 0);

    var result = it.peekGrapheme();
    try std.testing.expect(result.?.start == 0);
    try std.testing.expect(result.?.end == 15);
    try std.testing.expect(it.i == 0);

    result = it.nextGrapheme();
    try std.testing.expect(result.?.start == 0);
    try std.testing.expect(result.?.end == 15);
    try std.testing.expect(it.i == 15);
    try std.testing.expect(std.mem.eql(u8, str[result.?.start..result.?.end], "👩🏽‍🚀"));

    result = it.nextGrapheme();
    try std.testing.expect(result.?.start == 15);
    try std.testing.expect(result.?.end == 23);
    try std.testing.expect(it.i == 23);
    try std.testing.expect(std.mem.eql(u8, str[result.?.start..result.?.end], "🇨🇭"));

    result = it.peekGrapheme();
    try std.testing.expect(result.?.start == 23);
    try std.testing.expect(result.?.end == str.len);
    try std.testing.expect(std.mem.eql(u8, str[result.?.start..result.?.end], "👨🏻‍🍼"));

    result = it.nextGrapheme();
    try std.testing.expect(result.?.start == 23);
    try std.testing.expect(result.?.end == str.len);
    try std.testing.expect(it.i == str.len);

    try std.testing.expect(it.peekGrapheme() == null);
    try std.testing.expect(it.nextGrapheme() == null);
    try std.testing.expect(it.nextGrapheme() == null);
}

pub const BreakState = enum(u3) {
    default,
    regional_indicator,
    extended_pictographic,
    indic_conjunct_break_consonant,
    indic_conjunct_break_linker,
};

pub fn computeGraphemeBreak(
    gb1: types.GraphemeBreak,
    gb2: types.GraphemeBreak,
    state: *BreakState,
) bool {
    // Set state back to default when `gb1` or `gb2` is not expected in sequence.
    switch (state.*) {
        .regional_indicator => {
            if (gb1 != .regional_indicator or gb2 != .regional_indicator) {
                state.* = .default;
            }
        },
        .extended_pictographic => {
            switch (gb1) {
                // Keep state if in possibly valid sequence
                .indic_conjunct_break_extend, // extend
                .indic_conjunct_break_linker, // extend
                .zwnj, // extend
                .zwj,
                .extended_pictographic,
                .emoji_modifier_base,
                .emoji_modifier,
                => {},

                else => state.* = .default,
            }

            switch (gb2) {
                // Keep state if in possibly valid sequence
                .indic_conjunct_break_extend, // extend
                .indic_conjunct_break_linker, // extend
                .zwnj, // extend
                .zwj,
                .extended_pictographic,
                .emoji_modifier_base,
                .emoji_modifier,
                => {},

                else => state.* = .default,
            }
        },
        .indic_conjunct_break_consonant, .indic_conjunct_break_linker => {
            switch (gb1) {
                // Keep state if in possibly valid sequence
                .indic_conjunct_break_consonant,
                .indic_conjunct_break_linker,
                .indic_conjunct_break_extend,
                .zwj, // indic_conjunct_break_extend
                => {},

                else => state.* = .default,
            }

            switch (gb2) {
                // Keep state if in possibly valid sequence
                .indic_conjunct_break_consonant,
                .indic_conjunct_break_linker,
                .indic_conjunct_break_extend,
                .zwj, // indic_conjunct_break_extend
                => {},

                else => state.* = .default,
            }
        },
        .default => {},
    }

    // GB3: CR x LF
    if (gb1 == .cr and gb2 == .lf) return false;

    // GB4: Control
    if (gb1 == .control or gb1 == .cr or gb1 == .lf) return true;

    // GB5: Control
    if (gb2 == .control or gb2 == .cr or gb2 == .lf) return true;

    // GB6: L x (L | V | LV | VT)
    if (gb1 == .l) {
        if (gb2 == .l or
            gb2 == .v or
            gb2 == .lv or
            gb2 == .lvt) return false;
    }

    // GB7: (LV | V) x (V | T)
    if (gb1 == .lv or gb1 == .v) {
        if (gb2 == .v or gb2 == .t) return false;
    }

    // GB8: (LVT | T) x T
    if (gb1 == .lvt or gb1 == .t) {
        if (gb2 == .t) return false;
    }

    // Handle GB9 (Extend | ZWJ) later, since it can also match the start of
    // GB9c (Indic) and GB11 (Emoji ZWJ)

    // GB9a: SpacingMark
    if (gb2 == .spacing_mark) return false;

    // GB9b: Prepend
    if (gb1 == .prepend) return false;

    // GB9c: Indic
    if (gb1 == .indic_conjunct_break_consonant) {
        // start of sequence:

        // In normal operation, we'll be in this state, but
        // buildGraphemeBreakTable iterates all states.
        //inlineAssert(state.* == .default);

        if (isIndicConjunctBreakExtend(gb2)) {
            state.* = .indic_conjunct_break_consonant;
            return false;
        } else if (gb2 == .indic_conjunct_break_linker) {
            // jump straight to linker state
            state.* = .indic_conjunct_break_linker;
            return false;
        }
        // else, not an Indic sequence

    } else if (state.* == .indic_conjunct_break_consonant) {
        // consonant state:

        if (gb2 == .indic_conjunct_break_linker) {
            // consonant -> linker transition
            state.* = .indic_conjunct_break_linker;
            return false;
        } else if (isIndicConjunctBreakExtend(gb2)) {
            // continue [extend]* sequence
            return false;
        } else {
            // Not a valid Indic sequence
            state.* = .default;
        }
    } else if (state.* == .indic_conjunct_break_linker) {
        // linker state:

        if (gb2 == .indic_conjunct_break_linker or
            isIndicConjunctBreakExtend(gb2))
        {
            // continue [extend linker]* sequence
            return false;
        } else if (gb2 == .indic_conjunct_break_consonant) {
            // linker -> end of sequence
            state.* = .default;
            return false;
        } else {
            // Not a valid Indic sequence
            state.* = .default;
        }
    }

    // GB11: Emoji ZWJ sequence and Emoji modifier sequence
    if (isExtendedPictographic(gb1)) {
        // start of sequence:

        // In normal operation, we'll be in this state, but
        // buildGraphemeBreakTable iterates all states.
        // inlineAssert(state.* == .default);

        if (isExtend(gb2) or gb2 == .zwj) {
            state.* = .extended_pictographic;
            return false;
        }

        // The `emoji_modifier_sequence` case is described in the comment for
        // `isExtend` above, from UTS #51.
        if (gb1 == .emoji_modifier_base and gb2 == .emoji_modifier) {
            state.* = .extended_pictographic;
            return false;
        }

        // else, not an Emoji ZWJ sequence
    } else if (state.* == .extended_pictographic) {
        // continue or end sequence:

        if ((isExtend(gb1) or gb1 == .emoji_modifier) and
            (isExtend(gb2) or gb2 == .zwj))
        {
            // continue extend* ZWJ sequence
            return false;
        } else if (gb1 == .zwj and isExtendedPictographic(gb2)) {
            // ZWJ -> end of sequence
            state.* = .default;
            return false;
        } else {
            // Not a valid Emoji ZWJ sequence
            state.* = .default;
        }
    }

    // GB12 and GB13: Regional Indicator
    if (gb1 == .regional_indicator and gb2 == .regional_indicator) {
        if (state.* == .default) {
            state.* = .regional_indicator;
            return false;
        } else {
            state.* = .default;
            return true;
        }
    }

    // GB9: x (Extend | ZWJ)
    if (isExtend(gb2) or gb2 == .zwj) return false;

    // GB999: Otherwise, break everywhere
    return true;
}

fn isIndicConjunctBreakExtend(gb: types.GraphemeBreak) bool {
    return gb == .indic_conjunct_break_extend or gb == .zwj;
}

// Despite `emoji_modifier` being `extend` according to
// GraphemeBreakProperty.txt and UAX #29 (in addition to tests in
// GraphemeBreakTest.txt), UTS #51 states: `emoji_modifier_sequence :=
// emoji_modifier_base emoji_modifier` in ED-13 (emoji modifier sequence) under
// 1.4.4 (Emoji Modifiers), and: "When used alone, the default representation
// of these modifier characters is a color swatch... To have an effect on an
// emoji, an emoji modifier must immediately follow that base emoji
// character." in 2.4 (Diversity). Additionally it states "Skin tone
// modifiers and hair components should be
// displayed even in isolation" in ED-20 (basic emoji set) under 1.4.6 (Emoji
// Sets). See this revision of UAX #29 when the grapheme cluster break
// properties were simplified to remove `E_Base` and `E_Modifier`:
// http://www.unicode.org/reports/tr29/tr29-32.html
// Here we decide to diverge from the grapheme break spec, which is allowed
// under "tailored" grapheme clusters.
fn isExtend(gb: types.GraphemeBreak) bool {
    return gb == .zwnj or
        gb == .indic_conjunct_break_extend or
        gb == .indic_conjunct_break_linker;
}

fn isExtendedPictographic(gb: types.GraphemeBreak) bool {
    return gb == .extended_pictographic or gb == .emoji_modifier_base;
}

fn testGraphemeBreak(getActualIsBreak: fn (cp1: u21, cp2: u21, state: *BreakState) bool) !void {
    const comps = @import("config.zig").components;

    const trim = comps.trim;
    const parseCp = comps.parseCp;

    const allocator = std.testing.allocator;
    const file_path = "ucd/auxiliary/GraphemeBreakTest.txt";

    const file = try std.Io.Dir.cwd().openFile(std.testing.io, file_path, .{});
    defer file.close(std.testing.io);

    var buf: [2048]u8 = undefined;
    var file_reader = file.reader(std.testing.io, &buf);
    const content = try file_reader.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var success = true;

    var line_num: usize = 1;

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = trim(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ' ');
        const start = parts.next().?;
        try std.testing.expect(std.mem.eql(u8, start, "÷"));

        var state: BreakState = .default;
        var cp1 = try parseCp(parts.next().?);
        var gb1 = get(.grapheme_break, cp1);
        var expected_str = parts.next().?;
        var cp2 = try parseCp(parts.next().?);
        var gb2 = get(.grapheme_break, cp2);
        var next_expected_str = parts.next().?;

        while (true) {
            var expected_is_break = std.mem.eql(u8, expected_str, "÷");
            const actual_is_break = getActualIsBreak(cp1, cp2, &state);
            try std.testing.expect(expected_is_break or std.mem.eql(u8, expected_str, "×"));
            // GraphemeBreakTest.txt has tests for UAX #29 treating emoji
            // modifier as extend, always, but we diverge from that (see
            // comment above `isExtend`).
            if (gb2 == .emoji_modifier and gb1 != .emoji_modifier_base) {
                inlineAssert(!expected_is_break);
                expected_is_break = true;
            }
            if (actual_is_break != expected_is_break) {
                std.log.err("line={d} cp1={x}, cp2={x}: gb1={}, gb2={}, state={}, expected={}, actual={}", .{
                    line_num,
                    cp1,
                    cp2,
                    gb1,
                    gb2,
                    state,
                    expected_is_break,
                    actual_is_break,
                });
                success = false;
            }

            if (parts.peek() == null) break;

            cp1 = cp2;
            gb1 = gb2;
            expected_str = next_expected_str;
            cp2 = try parseCp(parts.next().?);
            gb2 = get(.grapheme_break, cp2);
            next_expected_str = parts.next().?;
        }

        try std.testing.expect(std.mem.eql(u8, next_expected_str, "÷"));
    }

    try std.testing.expect(success);
}

fn testGetActualComputedGraphemeBreak(cp1: u21, cp2: u21, state: *BreakState) bool {
    const gb1 = get(.grapheme_break, cp1);
    const gb2 = get(.grapheme_break, cp2);
    return computeGraphemeBreak(gb1, gb2, state);
}

test "GraphemeBreakTest.txt - computeGraphemeBreak" {
    try testGraphemeBreak(testGetActualComputedGraphemeBreak);
}

pub fn GraphemeBreakTable(comptime GB: type, comptime State: type) type {
    const Result = packed struct {
        result: bool,
        state: State,
    };
    const gb_fields = @typeInfo(GB).@"enum".fields;
    const state_fields = @typeInfo(State).@"enum".fields;
    const n_gb = gb_fields.len;
    const n_gb_2 = n_gb * n_gb;
    const n_state = state_fields.len;
    const n = n_state * n_gb_2;

    // Assert that these are simple enums (this isn't a full assertion, but
    // likely good enough.)
    inlineAssert(gb_fields[gb_fields.len - 1].value == n_gb - 1);
    inlineAssert(state_fields[state_fields.len - 1].value == n_state - 1);

    return struct {
        data: [n]Result,

        inline fn index(gb1: GB, gb2: GB, state: State) usize {
            return @intFromEnum(state) * n_gb_2 + @intFromEnum(gb1) * n_gb + @intFromEnum(gb2);
        }

        pub fn set(self: *@This(), gb1: GB, gb2: GB, state: State, result: Result) void {
            self.data[index(gb1, gb2, state)] = result;
        }

        pub fn get(self: @This(), gb1: GB, gb2: GB, state: State) Result {
            return self.data[index(gb1, gb2, state)];
        }
    };
}

pub fn buildGraphemeBreakTable(
    comptime GB: type,
    comptime State: type,
    compute: fn (gb1: GB, gb2: GB, state: *State) bool,
) GraphemeBreakTable(GB, State) {
    @setEvalBranchQuota(20_000);
    var table: GraphemeBreakTable(GB, State) = undefined;

    const gb_fields = @typeInfo(GB).@"enum".fields;
    const state_fields = @typeInfo(State).@"enum".fields;

    for (state_fields) |state_field| {
        for (gb_fields) |gb1_field| {
            for (gb_fields) |gb2_field| {
                const original_state: State = @enumFromInt(state_field.value);
                const gb1: GB = @enumFromInt(gb1_field.value);
                const gb2: GB = @enumFromInt(gb2_field.value);
                var state = original_state;
                const result = compute(gb1, gb2, &state);
                table.set(gb1, gb2, original_state, .{
                    .result = result,
                    .state = state,
                });
            }
        }
    }

    return table;
}

pub fn precomputedGraphemeBreak(
    gb1: types.GraphemeBreak,
    gb2: types.GraphemeBreak,
    state: *BreakState,
) bool {
    const table = comptime buildGraphemeBreakTable(
        types.GraphemeBreak,
        BreakState,
        computeGraphemeBreak,
    );
    // 5 BreakState fields x (20 GraphemeBreak fields)^2 = 2000
    inlineAssert(@sizeOf(@TypeOf(table)) == 2000);
    const result = table.get(gb1, gb2, state.*);
    state.* = result.state;
    return result.result;
}

pub fn isBreak(
    cp1: u21,
    cp2: u21,
    state: *BreakState,
) bool {
    const gb1 = get(.grapheme_break, cp1);
    const gb2 = get(.grapheme_break, cp2);
    return precomputedGraphemeBreak(gb1, gb2, state);
}

test "GraphemeBreakTest.txt - isBreak" {
    try testGraphemeBreak(isBreak);
}

test "long emoji zwj sequences" {
    // 👩‍👩‍👧‍👦 (family: woman, woman, girl, boy)
    var it = utf8Iterator("\u{1F469}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}_");
    var result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F469); // 👩
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D);
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F469); // 👩
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D);
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F467); // 👧
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D);
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F466); // 👦
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == '_');
    try std.testing.expect(result.?.is_break); // break
}

test "long emoji zwj sequences with emoji modifiers" {
    // 👨🏻‍❤️‍👨🏿 Kiss: man, man, light skin tone, dark skin tone
    var it = utf8Iterator("\u{1F468}\u{1F3FB}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F48B}\u{200D}\u{1F468}\u{1F3FF}_");

    var result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F468); // Man
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F3FB); // Light Skin Tone
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D); // ZWJ
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x2764); // Heart
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0xFE0F); // VS16
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D); // ZWJ
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F48B); // Kiss Mark
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D); // ZWJ
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F468); // Man
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F3FF); // Dark Skin Tone
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == '_');
    try std.testing.expect(result.?.is_break); // break (emoji_mod)
}

test "sequence of regional indicators" {
    // 🇺🇸🇦🇹🇼_🇳_
    var it = utf8Iterator("\u{1F1FA}\u{1F1F8}\u{1F1E6}\u{1F1F9}\u{1F1FC}_\u{1F1F3}_");

    var result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1FA); // U
    try std.testing.expect(it.state == .regional_indicator);
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1F8); // S
    try std.testing.expect(it.state == .default);
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1E6); // A
    try std.testing.expect(!result.?.is_break);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1F9); // T
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1FC); // W
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == '_');
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1F3); // N
    try std.testing.expect(result.?.is_break); // break

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == '_');
    try std.testing.expect(result.?.is_break); // break
}

// `wcwidth` (and `wcwidthRemaining`/`utf8Wcwidth`) are the full grapheme
// cluster calculation of the expected width in cells of a monospaced font.
// It is not part of the Unicode standard.
//
// See `src/components.zig` (Wcwidth) for the logic determining the width of
// a single code point standing alone, as well as a number of notes describing
// the choices the implementation makes.
//
// This implementation makes the following choices:
//
// * Only the context of the current grapheme cluster affects the width. The
//   width of a string of grapheme clusters is the sum of the widths of the
//   individual clusters.
//
// * Grapheme clusters with a single code point simply return
//   `wcwidth_standalone`. See `src/components.zig` (Wcwidth) for all the
//   considerations determining this value.
//
// * The general calculation of the width of a grapheme cluster is the sum of
//   the widths of the individual code points, using
//   `wcwidth_zero_in_grapheme` to treat a code point as width 0 in a multi-
//   code-point grapheme cluster, otherwise using `wcwidth_standalone` for the
//   widths of the code points.
//
//   Some alternative wcwidth implementations (see resources/wcwidth) only use
//   the width of the first non-zero width code point, but this does not
//   properly handle scripts such as Devanagari and Hangul, where multiple
//   code points in the grapheme cluster may have non-zero width, and the
//   resulting width is better represented by the sum.
//
// * Valid emoji sequences with VS16 (U+FEOF) return width 2, while
//   valid text sequences with VS15 (U+FE0E) return width 1.
//
// * Emoji modifiers following an emoji modifier base force an emoji
//   presentation, so the width will be 2.
//
// * Emoji ZWJ (zero-width joiner) sequences are a special case and the width
//   of the emoji code points following the ZWJ are not added to the sum.
//
// * Regional indicator sequences are given a width of 2.
//
// * In contrast to `resources/wcwidth/unicode_width.rs`, this implementation
//   does not include a large number of exceptions, in order to keep the
//   complexity down.
//
//   While the Unicode General Punctuation doc
//   (https://www.unicode.org/charts/PDF/Unicode-17.0/U170-2000.pdf) notes
//   that U+2018, U+2019, U+201C and U+201D followed by U+FE02 (VS-2) should
//   be fullwidth (width 2), we treat them as width 1 for simplicity.
//
//   Rather than treat CJK contexts differently, we always choose East Asian
//   Width (UAX #11) Ambiguous width (A) as width 1. See
//   `src/components.zig` (Wcwidth) for more info.

// This calculates the width of just a single grapheme, advancing the iterator.
// See `wcwidth` for a version that doesn't advance the iterator (accepting a
// constant iterator), `wcwidthRemaining` for a version that calculates the
// width of the remaining graphemes in the iterator, and `utf8Wcwidth` for the
// width of a string.
pub fn wcwidthNext(it: anytype) usize {
    inlineAssert(@typeInfo(@TypeOf(it)) == .pointer);

    const first = it.nextCodePoint() orelse return 0;

    var prev_cp: u21 = first.code_point;
    const standalone = get(.wcwidth_standalone, prev_cp);

    if (first.is_break) return standalone;

    var width: usize = if (get(.wcwidth_zero_in_grapheme, prev_cp))
        0
    else
        standalone;

    var prev_state: BreakState = it.state;
    inlineAssert(it.peekCodePoint() != null);

    code_points: while (it.nextCodePoint()) |result| {
        switch (result.code_point) {
            0xFE0F => {
                if (get(.is_emoji_vs_base, prev_cp)) {
                    width = 2;
                }
            },
            0xFE0E => {
                if (get(.is_emoji_vs_base, prev_cp)) {
                    width = 1;
                }
            },
            0x200D => {
                if (prev_state == .extended_pictographic and
                    !result.is_break)
                {
                    const next = it.nextCodePoint() orelse unreachable;
                    if (next.is_break) break;
                    prev_cp = next.code_point;
                    prev_state = it.state;
                    continue :code_points;
                }
            },
            0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF => {
                width = 2;
                inlineAssert(
                    (comptime !getpkg.hasField("is_emoji_modifier_base")) or
                        get(.is_emoji_modifier_base, prev_cp),
                );
            },
            else => {
                if (prev_state == .regional_indicator) {
                    width = 2;
                } else if (!get(.wcwidth_zero_in_grapheme, result.code_point)) {
                    width += get(.wcwidth_standalone, result.code_point);
                }
            },
        }

        if (result.is_break) break;

        prev_cp = result.code_point;
        prev_state = it.state;
    }

    return width;
}

pub fn wcwidth(const_it: anytype) usize {
    var it = const_it;
    return wcwidthNext(&it);
}

pub fn wcwidthRemaining(it: anytype) usize {
    var width: usize = 0;
    while (it.next_cp != null) {
        width += wcwidthNext(it);
    }
    return width;
}

pub fn utf8Wcwidth(s: []const u8) usize {
    var it = utf8Iterator(s);
    return wcwidthRemaining(&it);
}

test "wcwidthNext iterator state" {
    const str = "A\u{0300}B";
    var it = utf8Iterator(str);

    const w1 = wcwidthNext(&it);
    try std.testing.expectEqual(1, w1);
    try std.testing.expectEqual(3, it.i);

    const w2 = wcwidthNext(&it);
    try std.testing.expectEqual(1, w2);
    try std.testing.expectEqual(4, it.i);

    try std.testing.expect(it.peekCodePoint() == null);
}

test "wcwidthRemaining" {
    var it1 = utf8Iterator("A\u{0300}B");
    try std.testing.expectEqual(2, wcwidthRemaining(&it1));

    var it2 = utf8Iterator("ABC");
    try std.testing.expectEqual(3, wcwidthRemaining(&it2));

    var it3 = utf8Iterator("😀AB");
    try std.testing.expectEqual(4, wcwidthRemaining(&it3));

    var it4 = utf8Iterator("");
    try std.testing.expectEqual(0, wcwidthRemaining(&it4));

    var it5 = utf8Iterator("ABC");
    _ = wcwidthNext(&it5);
    try std.testing.expectEqual(2, wcwidthRemaining(&it5));
}

test "utf8Wcwidth" {
    try std.testing.expectEqual(2, utf8Wcwidth("A\u{0300}B"));
}

test "wcwidth{,Next,Remaining} README example" {
    const str = "ò👨🏻‍❤️‍👨🏿_";
    var it = utf8Iterator(str);

    try std.testing.expectEqual(1, wcwidth(it));

    try std.testing.expectEqual(1, wcwidthNext(&it));
    const grapheme_result = it.peekGrapheme();
    try std.testing.expectEqualStrings("👨🏻‍❤️‍👨🏿", str[grapheme_result.?.start..grapheme_result.?.end]);

    try std.testing.expectEqual(3, wcwidthRemaining(&it));

    try std.testing.expectEqual(4, utf8Wcwidth(str));
}

test "wcwidth ascii" {
    const it1 = utf8Iterator("A");
    try std.testing.expectEqual(1, wcwidth(it1));
    const it2 = utf8Iterator("1");
    try std.testing.expectEqual(1, wcwidth(it2));
}

test "wcwidth control" {
    const it1 = utf8Iterator("\x00");
    try std.testing.expectEqual(0, wcwidth(it1));
    const it2 = utf8Iterator("\x7F");
    try std.testing.expectEqual(0, wcwidth(it2));
}

test "wcwidth default ignorable" {
    const it1 = utf8Iterator("\u{200B}");
    try std.testing.expectEqual(0, wcwidth(it1));
    const it2 = utf8Iterator("\u{3164}");
    try std.testing.expectEqual(0, wcwidth(it2));
}

test "wcwidth marks standing alone" {
    const it = utf8Iterator("\u{0300}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth keycap standing alone" {
    const it = utf8Iterator("\u{20E3}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth regional indicator standing alone" {
    const it = utf8Iterator("\u{1F1E6}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth emoji" {
    const it = utf8Iterator("😀");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth ambiguous" {
    const it = utf8Iterator("\u{00A1}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth fullwidth" {
    const it = utf8Iterator("\u{3000}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth soft hyphen" {
    const it = utf8Iterator("\u{00AD}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth sequence base + nonspacing marks" {
    const it = utf8Iterator("A\u{0300}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth sequence base + spacing marks" {
    const it = utf8Iterator("\u{0905}\u{0903}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji + modifier" {
    const it = utf8Iterator("\u{1F466}\u{1F3FB}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji with default text presentation + modifier" {
    const it = utf8Iterator("\u{1F3CB}\u{1F3FE}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji with default text presentation + VS16" {
    const it = utf8Iterator("\u{2601}\u{FE0F}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji with default text presentation + VS15" {
    const it = utf8Iterator("\u{2601}\u{FE0E}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth sequence emoji with default emoji presentation + VS16" {
    const it = utf8Iterator("\u{23F0}\u{FE0F}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji not in emoji-variation-sequences + VS16" {
    const it = utf8Iterator("\u{1F5FF}\u{FE0F}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji not in emoji-variation-sequences + VS15" {
    const it = utf8Iterator("\u{1F5FF}\u{FE0E}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence text not in emoji-variation-sequences + VS16" {
    const it = utf8Iterator("V\u{FE0F}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth sequence text not in emoji-variation-sequences + VS15" {
    const it = utf8Iterator("V\u{FE0E}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth sequence emoji with default emoji presentation + VS15" {
    const it = utf8Iterator("\u{23F0}\u{FE0E}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth sequence keycap" {
    const it = utf8Iterator("1\u{FE0F}\u{20E3}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence regional indicator full" {
    const it = utf8Iterator("\u{1F1FA}\u{1F1F8}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji zwj" {
    const it = utf8Iterator("\u{1F468}\u{200D}\u{1F33E}_");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji zwj long" {
    const it = utf8Iterator("\u{1F469}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}_");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth sequence emoji zwj long with emoji modifiers" {
    const it = utf8Iterator("\u{1F468}\u{1F3FB}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F48B}\u{200D}\u{1F468}\u{1F3FF}_");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth Hangul L+V" {
    const it = utf8Iterator("\u{1100}\u{1161}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth Hangul L+V+T" {
    const it = utf8Iterator("\u{1100}\u{1161}\u{11A8}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth Hangul L+L+V" {
    const it = utf8Iterator("\u{1100}\u{1100}\u{1161}");
    try std.testing.expectEqual(4, wcwidth(it));
}

test "wcwidth Hangul LV+T" {
    const it = utf8Iterator("\u{AC00}\u{11A8}");
    try std.testing.expectEqual(2, wcwidth(it));
}

test "wcwidth Devanagari with ZWJ" {
    const str = "क्‍ष";
    const it = Iterator(utf8.Iterator).init(.init(str));
    try std.testing.expect(wcwidth(it) == 2);
}

test "wcwidth Devanagari 3 consonants" {
    const it = utf8Iterator("\u{0915}\u{094D}\u{0915}\u{094D}\u{0915}");
    try std.testing.expectEqual(3, wcwidth(it));
}

test "wcwidth prepend characters standing alone are width 1" {
    const it = utf8Iterator("\u{0D4E}");
    try std.testing.expectEqual(1, wcwidth(it));
}

test "wcwidth prepend characters don't contribute to width in grapheme cluster" {
    const it = utf8Iterator("\u{0D4E}\u{0D39}");
    try std.testing.expectEqual(1, wcwidth(it));
}

pub fn IteratorNoControl(comptime CodePointIterator: type) type {
    return CustomIterator(
        CodePointIterator,
        types.GraphemeBreakNoControl,
        BreakState,
        .grapheme_break_no_control,
        precomputedGraphemeBreakNoControl,
    );
}

pub fn utf8IteratorNoControl(bytes: []const u8) IteratorNoControl(utf8.Iterator) {
    return IteratorNoControl(utf8.Iterator).init(.init(bytes));
}

test "IteratorNoControl nextCodePoint/peekCodePoint" {
    const str = "👩🏽‍🚀🇨🇭";
    var it = utf8IteratorNoControl(str);
    try std.testing.expect(it.i == 0);

    var result = it.peekCodePoint();
    try std.testing.expect(it.i == 0);
    try std.testing.expect(result.?.code_point == 0x1F469);
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(it.i == 4);
    try std.testing.expect(result.?.code_point == 0x1F469);
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F3FD);
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x200D);
    try std.testing.expect(result.?.is_break == false);

    result = it.peekCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F680);
    try std.testing.expect(result.?.is_break == true);

    result = it.nextCodePoint();
    try std.testing.expect(it.i == 15);
    try std.testing.expect(result.?.code_point == 0x1F680);
    try std.testing.expect(result.?.is_break == true);
    try std.testing.expect(std.mem.eql(u8, str[0..it.i], "👩🏽‍🚀"));

    result = it.nextCodePoint();
    try std.testing.expect(result.?.code_point == 0x1F1E8);
    try std.testing.expect(result.?.is_break == false);

    result = it.nextCodePoint();
    try std.testing.expect(it.i == str.len);
    try std.testing.expect(result.?.code_point == 0x1F1ED);
    try std.testing.expect(result.?.is_break == true);

    try std.testing.expect(it.peekCodePoint() == null);
    try std.testing.expect(it.nextCodePoint() == null);
    try std.testing.expect(it.nextCodePoint() == null);
}

// This is a copy of `computeGraphemeBreak` but with the rules for `control`,
// `cr`, and `lf` ignored, since `grapheme_break_no_control` maps them to
// `other` as these are assumed to have been handled prior or stripped from
// the input.
pub fn computeGraphemeBreakNoControl(
    gb1: types.GraphemeBreakNoControl,
    gb2: types.GraphemeBreakNoControl,
    state: *BreakState,
) bool {
    switch (state.*) {
        .regional_indicator => {
            if (gb1 != .regional_indicator or gb2 != .regional_indicator) {
                state.* = .default;
            }
        },
        .extended_pictographic => {
            switch (gb1) {
                .indic_conjunct_break_extend,
                .indic_conjunct_break_linker,
                .zwnj,
                .zwj,
                .extended_pictographic,
                .emoji_modifier_base,
                .emoji_modifier,
                => {},

                else => state.* = .default,
            }

            switch (gb2) {
                .indic_conjunct_break_extend,
                .indic_conjunct_break_linker,
                .zwnj,
                .zwj,
                .extended_pictographic,
                .emoji_modifier_base,
                .emoji_modifier,
                => {},

                else => state.* = .default,
            }
        },
        .indic_conjunct_break_consonant, .indic_conjunct_break_linker => {
            switch (gb1) {
                .indic_conjunct_break_consonant,
                .indic_conjunct_break_linker,
                .indic_conjunct_break_extend,
                .zwj,
                => {},

                else => state.* = .default,
            }

            switch (gb2) {
                .indic_conjunct_break_consonant,
                .indic_conjunct_break_linker,
                .indic_conjunct_break_extend,
                .zwj,
                => {},

                else => state.* = .default,
            }
        },
        .default => {},
    }

    // GB6: L x (L | V | LV | VT)
    if (gb1 == .l) {
        if (gb2 == .l or
            gb2 == .v or
            gb2 == .lv or
            gb2 == .lvt) return false;
    }

    // GB7: (LV | V) x (V | T)
    if (gb1 == .lv or gb1 == .v) {
        if (gb2 == .v or gb2 == .t) return false;
    }

    // GB8: (LVT | T) x T
    if (gb1 == .lvt or gb1 == .t) {
        if (gb2 == .t) return false;
    }

    // GB9a: SpacingMark
    if (gb2 == .spacing_mark) return false;

    // GB9b: Prepend
    if (gb1 == .prepend) return false;

    // GB9c: Indic
    if (gb1 == .indic_conjunct_break_consonant) {
        if (isIndicConjunctBreakExtendNoControl(gb2)) {
            state.* = .indic_conjunct_break_consonant;
            return false;
        } else if (gb2 == .indic_conjunct_break_linker) {
            state.* = .indic_conjunct_break_linker;
            return false;
        }
    } else if (state.* == .indic_conjunct_break_consonant) {
        if (gb2 == .indic_conjunct_break_linker) {
            state.* = .indic_conjunct_break_linker;
            return false;
        } else if (isIndicConjunctBreakExtendNoControl(gb2)) {
            return false;
        } else {
            state.* = .default;
        }
    } else if (state.* == .indic_conjunct_break_linker) {
        if (gb2 == .indic_conjunct_break_linker or
            isIndicConjunctBreakExtendNoControl(gb2))
        {
            return false;
        } else if (gb2 == .indic_conjunct_break_consonant) {
            state.* = .default;
            return false;
        } else {
            state.* = .default;
        }
    }

    // GB11: Emoji ZWJ sequence and Emoji modifier sequence
    if (isExtendedPictographicNoControl(gb1)) {
        if (isExtendNoControl(gb2) or gb2 == .zwj) {
            state.* = .extended_pictographic;
            return false;
        }

        if (gb1 == .emoji_modifier_base and gb2 == .emoji_modifier) {
            state.* = .extended_pictographic;
            return false;
        }
    } else if (state.* == .extended_pictographic) {
        if ((isExtendNoControl(gb1) or gb1 == .emoji_modifier) and
            (isExtendNoControl(gb2) or gb2 == .zwj))
        {
            return false;
        } else if (gb1 == .zwj and isExtendedPictographicNoControl(gb2)) {
            state.* = .default;
            return false;
        } else {
            state.* = .default;
        }
    }

    // GB12 and GB13: Regional Indicator
    if (gb1 == .regional_indicator and gb2 == .regional_indicator) {
        if (state.* == .default) {
            state.* = .regional_indicator;
            return false;
        } else {
            state.* = .default;
            return true;
        }
    }

    // GB9: x (Extend | ZWJ)
    if (isExtendNoControl(gb2) or gb2 == .zwj) return false;

    // GB999: Otherwise, break everywhere
    return true;
}

fn isIndicConjunctBreakExtendNoControl(gb: types.GraphemeBreakNoControl) bool {
    return gb == .indic_conjunct_break_extend or gb == .zwj;
}

// Despite `emoji_modifier` being `extend` according to
// GraphemeBreakProperty.txt and UAX #29 (in addition to tests in
// GraphemeBreakTest.txt), UTS #51 states: `emoji_modifier_sequence :=
// emoji_modifier_base emoji_modifier` in ED-13 (emoji modifier sequence) under
// 1.4.4 (Emoji Modifiers), and: "When used alone, the default representation
// of these modifier characters is a color swatch... To have an effect on an
// emoji, an emoji modifier must immediately follow that base emoji
// character." in 2.4 (Diversity). Additionally it states "Skin tone
// modifiers and hair components should be
// displayed even in isolation" in ED-20 (basic emoji set) under 1.4.6 (Emoji
// Sets). See this revision of UAX #29 when the grapheme cluster break
// properties were simplified to remove `E_Base` and `E_Modifier`:
// http://www.unicode.org/reports/tr29/tr29-32.html
// Here we decide to diverge from the grapheme break spec, which is allowed
// under "tailored" grapheme clusters.
fn isExtendNoControl(gb: types.GraphemeBreakNoControl) bool {
    return gb == .zwnj or
        gb == .indic_conjunct_break_extend or
        gb == .indic_conjunct_break_linker;
}

fn isExtendedPictographicNoControl(gb: types.GraphemeBreakNoControl) bool {
    return gb == .extended_pictographic or gb == .emoji_modifier_base;
}

fn testGraphemeBreakNoControl(getActualIsBreak: fn (cp1: u21, cp2: u21, state: *BreakState) bool) !void {
    const comps = @import("config.zig").components;

    const trim = comps.trim;
    const parseCp = comps.parseCp;

    const allocator = std.testing.allocator;
    const file_path = "ucd/auxiliary/GraphemeBreakTest.txt";

    const file = try std.Io.Dir.cwd().openFile(std.testing.io, file_path, .{});
    defer file.close(std.testing.io);

    var buf: [2048]u8 = undefined;
    var file_reader = file.reader(std.testing.io, &buf);
    const content = try file_reader.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var success = true;

    var line_num: usize = 1;

    line_loop: while (lines.next()) |line| : (line_num += 1) {
        const trimmed = trim(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ' ');
        const start = parts.next().?;
        try std.testing.expect(std.mem.eql(u8, start, "÷"));

        var state: BreakState = .default;
        var cp1 = try parseCp(parts.next().?);
        var expected_str = parts.next().?;
        var cp2 = try parseCp(parts.next().?);

        const original_gb1 = get(.grapheme_break, cp1);
        var original_gb2 = get(.grapheme_break, cp2);
        if (original_gb1 == .control or
            original_gb1 == .cr or
            original_gb1 == .lf or
            original_gb2 == .control or
            original_gb2 == .cr or
            original_gb2 == .lf) continue :line_loop;

        var gb1 = get(.grapheme_break_no_control, cp1);
        var gb2 = get(.grapheme_break_no_control, cp2);
        var next_expected_str = parts.next().?;

        while (true) {
            var expected_is_break = std.mem.eql(u8, expected_str, "÷");
            const actual_is_break = getActualIsBreak(cp1, cp2, &state);
            try std.testing.expect(expected_is_break or std.mem.eql(u8, expected_str, "×"));
            if (gb2 == .emoji_modifier and gb1 != .emoji_modifier_base) {
                inlineAssert(!expected_is_break);
                expected_is_break = true;
            }
            if (actual_is_break != expected_is_break) {
                std.log.err("line={d} cp1={x}, cp2={x}: gb1={}, gb2={}, state={}, expected={}, actual={}", .{
                    line_num,
                    cp1,
                    cp2,
                    gb1,
                    gb2,
                    state,
                    expected_is_break,
                    actual_is_break,
                });
                success = false;
            }

            if (parts.peek() == null) break;

            cp1 = cp2;
            gb1 = gb2;
            expected_str = next_expected_str;
            cp2 = try parseCp(parts.next().?);
            original_gb2 = get(.grapheme_break, cp2);
            if (original_gb2 == .control or
                original_gb2 == .cr or
                original_gb2 == .lf) continue :line_loop;

            gb2 = get(.grapheme_break_no_control, cp2);
            next_expected_str = parts.next().?;
        }

        try std.testing.expect(std.mem.eql(u8, next_expected_str, "÷"));
    }

    try std.testing.expect(success);
}

fn testGetActualComputedGraphemeBreakNoControl(cp1: u21, cp2: u21, state: *BreakState) bool {
    const gb1 = get(.grapheme_break_no_control, cp1);
    const gb2 = get(.grapheme_break_no_control, cp2);
    return computeGraphemeBreakNoControl(gb1, gb2, state);
}

test "GraphemeBreakTest.txt - computeGraphemeBreakNoControl" {
    try testGraphemeBreakNoControl(testGetActualComputedGraphemeBreakNoControl);
}

pub fn precomputedGraphemeBreakNoControl(
    gb1: types.GraphemeBreakNoControl,
    gb2: types.GraphemeBreakNoControl,
    state: *BreakState,
) bool {
    const table = comptime buildGraphemeBreakTable(
        types.GraphemeBreakNoControl,
        BreakState,
        computeGraphemeBreakNoControl,
    );
    // 5 BreakState fields x (17 GraphemeBreak fields)^2 = 1445
    inlineAssert(@sizeOf(@TypeOf(table)) == 1445);
    const result = table.get(gb1, gb2, state.*);
    state.* = result.state;
    return result.result;
}

pub fn isBreakNoControl(
    cp1: u21,
    cp2: u21,
    state: *BreakState,
) bool {
    const gb1 = get(.grapheme_break_no_control, cp1);
    const gb2 = get(.grapheme_break_no_control, cp2);
    return precomputedGraphemeBreakNoControl(gb1, gb2, state);
}

test "GraphemeBreakTest.txt - isBreakNoControl" {
    try testGraphemeBreakNoControl(isBreakNoControl);
}
