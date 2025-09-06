const std = @import("std");

const types = @import("types.zig");
const get = @import("get.zig").get;

pub const BreakState = enum(u3) {
    default,
    regional_indicator,
    extended_pictographic,
    indic_conjunct_break_consonant,
    indic_conjunct_break_linker,
};

fn isIndicConjunctBreakExtend(gb: types.GraphemeBreak) bool {
    return gb == .indic_conjunct_break_extend or gb == .zwj;
}

fn isExtend(gb: types.GraphemeBreak) bool {
    return gb == .zwnj or
        gb == .indic_conjunct_break_extend or
        gb == .indic_conjunct_break_linker;
}

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
        // precomputeGraphemeBreak iterates all states.
        // std.debug.assert(state.* == .default);

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

    // GB11: Emoji ZWJ sequence
    if (gb1 == .extended_pictographic) {
        // start of sequence:

        // In normal operation, we'll be in this state, but
        // precomputeGraphemeBreak iterates all states.
        // std.debug.assert(state.* == .default);

        if (isExtend(gb2) or gb2 == .zwj) {
            state.* = .extended_pictographic;
            return false;
        }
        // else, not an Emoji ZWJ sequence
    } else if (state.* == .extended_pictographic) {
        // continue or end sequence:

        if (isExtend(gb1) and (isExtend(gb2) or gb2 == .zwj)) {
            // continue extend* ZWJ sequence
            return false;
        } else if (gb1 == .zwj and gb2 == .extended_pictographic) {
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

fn testGraphemeBreak(getActual: fn (cp1: u21, cp2: u21, state: *BreakState) bool) !void {
    const Ucd = @import("build/Ucd.zig");

    const stripComment = Ucd.stripComment;
    const parseCodePoint = Ucd.parseCodePoint;

    const allocator = std.testing.allocator;
    const file_path = "ucd/auxiliary/GraphemeBreakTest.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 10);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var success = true;

    var line_num: usize = 1;

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = stripComment(line);
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ' ');
        const start = parts.next().?;
        try std.testing.expect(std.mem.eql(u8, start, "÷"));

        var state: BreakState = .default;
        var cp1 = try parseCodePoint(parts.next().?);
        var expected_str = parts.next().?;
        var cp2 = try parseCodePoint(parts.next().?);
        var next_expected_str = parts.next().?;

        while (true) {
            const gb1 = get(.grapheme_break, cp1);
            const gb2 = get(.grapheme_break, cp2);
            const expected = std.mem.eql(u8, expected_str, "÷");
            const actual = getActual(cp1, cp2, &state);
            try std.testing.expect(expected or std.mem.eql(u8, expected_str, "×"));
            if (actual != expected) {
                std.log.err("line={d} cp1={x}, cp2={x}: gb1={}, gb2={}, state={}, expected={}, actual={}", .{ line_num, cp1, cp2, gb1, gb2, state, expected, actual });
                success = false;
            }

            if (parts.peek() == null) break;

            cp1 = cp2;
            expected_str = next_expected_str;
            cp2 = try parseCodePoint(parts.next().?);
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
    std.debug.assert(gb_fields[gb_fields.len - 1].value == n_gb - 1);
    std.debug.assert(state_fields[state_fields.len - 1].value == n_state - 1);

    return struct {
        data: [n]Result,

        fn index(gb1: GB, gb2: GB, state: State) usize {
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

pub fn precomputeGraphemeBreak(
    comptime GB: type,
    comptime State: type,
    compute: fn (gb1: GB, gb2: GB, state: *State) bool,
) GraphemeBreakTable(GB, State) {
    @setEvalBranchQuota(2_000_000);
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

pub fn isBreak(
    cp1: u21,
    cp2: u21,
    state: *BreakState,
) bool {
    const table = comptime precomputeGraphemeBreak(
        types.GraphemeBreak,
        BreakState,
        computeGraphemeBreak,
    );
    // 5 BreakState fields x 2 x 18 GraphemeBreak fields = 1620
    std.debug.assert(@sizeOf(@TypeOf(table)) == 1620);
    const gb1 = get(.grapheme_break, cp1);
    const gb2 = get(.grapheme_break, cp2);
    const result = table.get(gb1, gb2, state.*);
    state.* = result.state;
    return result.result;
}

test "GraphemeBreakTest.txt - isBreak" {
    try testGraphemeBreak(isBreak);
}
