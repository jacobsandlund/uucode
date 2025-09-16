const config = @import("config.zig");
const config_x = @import("config.x.zig");
const d = config.default;

pub const log_level = .debug;

fn computeFoo(cp: u21, data: anytype, b: anytype, t: anytype) void {
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

fn computeEmojiOddOrEven(cp: u21, data: anytype, backing: anytype, tracking: anytype) void {
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

// types must be marked `pub` and be able to be part of a packed struct.
pub const EmojiOddOrEven = enum(u2) {
    not_emoji,
    even_emoji,
    odd_emoji,
};

const emoji_odd_or_even = config.Extension{
    .inputs = &.{"is_emoji"},
    .compute = &computeEmojiOddOrEven,
    .fields = &.{
        .{ .name = "emoji_odd_or_even", .type = EmojiOddOrEven },
    },
};

pub const tables = [_]config.Table{
    .{
        .extensions = &.{
            foo,
            emoji_odd_or_even,
        },
        .fields = &.{
            foo.field("foo"),
            emoji_odd_or_even.field("emoji_odd_or_even"),
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
        .name = "needed_for_ref_all_decls",
        .extensions = &.{
            config_x.grapheme_break_pedantic_emoji,
        },
        .fields = &.{
            config_x.grapheme_break_pedantic_emoji.field("grapheme_break_pedantic_emoji"),
        },
    },
};
