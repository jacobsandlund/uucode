# uucode (Micro/µ Unicode)

TODO: greatly expand documentation in this README and in a static docs site.

Check out [AGENTS.md](./AGENTS.md) for a basic explanation. (I've not actually used agents that much but they're sometimes helpful for easier tasks.)

## Super basic usage

``` zig
const uucode = @import("uucode");

var cp: u21 = undefined;

//////////////////////
// getting properties

cp = 0x2200; // ∀
uucode.get(.general_category, cp) // .symbol_math

cp = 0x03C2; // ς
uucode.get(.simple_uppercase_mapping, cp) // U+03A3 == Σ

cp = 0x00DF; // ß
var buffer1: uucode.TypeOf(.uppercase_mapping).SliceBuffer = undefined;
uucode.get(.uppercase_mapping, cp).slice(&buffer1, cp) // "SS", but might not be in buffer1

var buffer2: uucode.TypeOf(.uppercase_mapping).CopyBuffer = undefined;
uucode.get(.uppercase_mapping, cp).copy(&buffer2, cp) // "SS", copied into buffer2

//////////////////////
// graphemeBreak

var break_state: uucode.GraphemeBreakState = .default;

var cp1: u21 = 0x1F469; // 👩
var cp2: u21 = 0x200D; // Zero width joiner

uucode.graphemeBreak(cp1, cp2, &break_state); // false

cp1 = cp2;
cp2 = 0x1F37C; // 🍼

// combined grapheme cluster is 👩‍🍼 (woman feeding baby)
uucode.graphemeBreak(cp1, cp2, &break_state); // false
```

### Configuration

Only include the Unicode fields you actually use:

``` zig
// In `build.zig`:
if (b.lazyDependency("uucode", .{
    .target = target,
    .optimize = optimize,
    .table_0_fields = @as([]const []const u8, .{
        "name",
        "general_category",
        "case_folding_simple",
        "is_alphabetic",
        // ...
    }),
})) |dep| {
    step.root_module.addImport("uucode", dep.module("uucode"));
}
```

#### Advanced configuration

``` zig
///////////////////////////////////////////////////////////
// In `build.zig`:
b.dependency("uucode", .{
    .target = target,
    .optimize = optimize,
    .build_config_path = b.path("src/build/uucode_config.zig"),
})

///////////////////////////////////////////////////////////
// `src/build/uucode_config.zig`:
const config = @import("config.zig");

// Use `config.x.zig` for extensions already built in to `uucode`.
const config_x = @import("config.x.zig");

const d = config.default;
const wcwidth = config_x.wcwidth;

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
            emoji_odd_or_even,
            wcwidth,
        },
        .fields = &.{
            emoji_odd_or_even.field("emoji_odd_or_even"),
            //wcwidth.field("wcwidth"),
            d.field("general_category"),
            d.field("block"),
            // ...
        },
    },
};

///////////////////////////////////////////////////////////
// In your code:
const uucode = @import("uucode");

// This uses `getX` because `get` only includes known properties to aid with
// LSP completion
uucode.getX(.emoji_odd_or_even, 0x1F34B) // 🍋 == .odd_emoji

// Built in extensions can use `get`
uucode.get(.wcwidth, 0x26F5) // ⛵ == 2
```
