const std = @import("std");
const config = @import("config.zig");
const config_x = @import("config.x.zig");
const d = config.default;

const Allocator = std.mem.Allocator;
pub const log_level = .debug;

fn computeFoo(
    allocator: Allocator,
    cp: u21,
    data: anytype,
    b: anytype,
    t: anytype,
) Allocator.Error!void {
    _ = allocator;
    _ = cp;
    _ = b;
    _ = t;
    data.foo = switch (data.original_grapheme_break) {
        .other => 0,
        .control => 3,
        else => 10,
    };
}

const foo = config.Extension{
    .inputs = &.{"original_grapheme_break"},
    .compute = &computeFoo,
    .fields = &.{
        .{ .name = "foo", .type = u8 },
    },
};

// Or build your own extension:
const emoji_odd_or_even = config.Extension{
    .inputs = &.{"is_emoji"},
    .compute = &computeEmojiOddOrEven,
    .fields = &.{
        .{ .name = "emoji_odd_or_even", .type = EmojiOddOrEven },
    },
};

fn computeEmojiOddOrEven(
    allocator: Allocator,
    cp: u21,
    data: anytype,
    backing: anytype,
    tracking: anytype,
) Allocator.Error!void {
    // allocator is an ArenaAllocator, so don't worry about freeing
    _ = allocator;

    // backing and tracking are only used for slice types (see
    // src/build/test_build_config.zig for examples).
    _ = backing;
    _ = tracking;

    if (!data.is_emoji) {
        data.emoji_odd_or_even = .not_emoji;
    } else if (cp % 2 == 0) {
        data.emoji_odd_or_even = .even_emoji;
    } else {
        data.emoji_odd_or_even = .odd_emoji;
    }
}

// Types must be marked `pub`
pub const EmojiOddOrEven = enum(u2) {
    not_emoji,
    even_emoji,
    odd_emoji,
};

const info = config.Extension{
    .inputs = &.{
        "uppercase_mapping",
        "numeric_value_numeric",
        "numeric_value_decimal",
        "simple_lowercase_mapping",
    },
    .compute = &computeInfo,
    .fields = &.{
        .{
            .name = "uppercase_mapping_first_char",
            .type = u21,
            .cp_packing = .shift,
            .shift_low = -64190,
            .shift_high = 42561,
        },
        .{ .name = "has_simple_lowercase", .type = bool },
        .{
            .name = "numeric_value_numeric_reversed",
            .type = []const u8,
            .max_len = 13,
            .max_offset = 503,
            .embedded_len = 1,
        },
    },
};

fn computeInfo(
    allocator: Allocator,
    cp: u21,
    data: anytype,
    backing: anytype,
    tracking: anytype,
) Allocator.Error!void {
    var single_item_buffer: [1]u21 = undefined;
    data.uppercase_mapping_first_char = .init(
        &tracking.uppercase_mapping_first_char,
        cp,
        data.uppercase_mapping.sliceWith(
            backing.uppercase_mapping,
            &single_item_buffer,
            cp,
        )[0],
    );

    data.has_simple_lowercase = data.simple_lowercase_mapping.unshift(cp) != null;

    var buffer: [13]u8 = undefined;
    for (data.numeric_value_numeric.slice(backing.numeric_value_numeric), 0..) |digit, i| {
        buffer[data.numeric_value_numeric.len - i - 1] = digit;
    }

    data.numeric_value_numeric_reversed = try .fromSlice(
        allocator,
        backing.numeric_value_numeric_reversed,
        &tracking.numeric_value_numeric_reversed,
        buffer[0..data.numeric_value_numeric.len],
    );
}

pub const tables = [_]config.Table{
    .{
        .extensions = &.{
            foo,
            emoji_odd_or_even,
            info,
        },
        .fields = &.{
            foo.field("foo"),
            emoji_odd_or_even.field("emoji_odd_or_even"),
            info.field("uppercase_mapping_first_char"),
            info.field("has_simple_lowercase"),
            info.field("numeric_value_numeric_reversed"),
            d.field("name").override(.{
                .embedded_len = 15,
                .max_offset = 986096,
            }),
            d.field("grapheme_break"),
            d.field("special_casing_condition"),
            d.field("special_lowercase_mapping"),
        },
    },
    .{
        .stages = .two,
        .fields = &.{
            d.field("general_category"),
            d.field("case_folding_simple"),
        },
    },
    .{
        .name = "checks",
        .extensions = &.{},
        .fields = &.{
            d.field("simple_uppercase_mapping"),
            d.field("is_alphabetic"),
            d.field("is_lowercase"),
            d.field("is_uppercase"),
        },
    },
    .{
        .name = "needed_for_tests",
        .extensions = &.{
            config_x.grapheme_break_pedantic_emoji,
            config_x.wcwidth,
        },
        .fields = &.{
            config_x.grapheme_break_pedantic_emoji.field("grapheme_break_pedantic_emoji"),
            config_x.wcwidth.field("wcwidth"),
        },
    },
};
