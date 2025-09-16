# uucode (Micro/µ Unicode)

TODO: greatly expand documentation in this README and in a static docs site.

See branch `zig-0.14` if you haven't migrated to `0.15` yet (this branch won't last forever).

## Super basic usage

``` zig
const uucode = @import("uucode");

var cp: u21 = undefined;

//////////////////////
// getting properties (see `src/config.zig` for a full list)

cp = 0x2200; // ∀
uucode.get(.general_category, cp) // .symbol_math

cp = 0x03C2; // ς
uucode.get(.simple_uppercase_mapping, cp) // U+03A3 == Σ

cp = 0x00DF; // ß
var buffer1: uucode.TypeOf(.uppercase_mapping).SliceBuffer = undefined;
uucode.get(.uppercase_mapping, cp).slice(&buffer1, cp) // "SS", but might not be in buffer1

var buffer2: uucode.TypeOf(.uppercase_mapping).CopyBuffer = undefined;
uucode.get(.uppercase_mapping, cp).copy(&buffer2, cp) // "SS", copied into buffer2

// Use `getAll` to get a group of properties for a code point together.
// The first argument is the name/index of the table ("0" for `fields`).
cp = 0x03C2; // ς
const data = uucode.getAll("0", cp);

data.simple_uppercase_mapping // U+03A3 == Σ
data.general_category // .letter_lowercase
std.debug.assert(@TypeOf(data) == uucode.TypeOfAll("0"))

//////////////////////
// grapheme_break

var break_state: uucode.grapheme.BreakState = .default;

var cp1: u21 = 0x1F469; // 👩
var cp2: u21 = 0x200D; // Zero width joiner

uucode.grapheme.isBreak(cp1, cp2, &break_state); // false

cp1 = cp2;
cp2 = 0x1F37C; // 🍼

// The combined grapheme cluster is 👩‍🍼 (woman feeding baby)
uucode.grapheme.isBreak(cp1, cp2, &break_state); // false

//////////////////////
// utf8.Iterator

// TODO: offer more alternatives (like reading into a code point buffer), SIMD,
// and do more testing and benchmarks
var iter = uucode.utf8.Iterator.init("😀😅😻👺");
iter.next(); // 0x1F600
iter.peek(); // 0x1F605
iter.next(); // 0x1F605
iter.next(); // 0x1F63B
iter.next(); // 0x1F47A
```

### Configuration

Only include the Unicode fields you actually use:

``` zig
// In `build.zig`:
if (b.lazyDependency("uucode", .{
    .target = target,
    .optimize = optimize,
    .fields = @as([]const []const u8, &.{
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

#### Multiple tables

Fields can be split into multiple tables using `field_0` through `fields_9`, to optimize how fields are stored and accessed:


``` zig
// In `build.zig`:
if (b.lazyDependency("uucode", .{
    .target = target,
    .optimize = optimize,
    .fields_0 = @as([]const []const u8, &.{
        "general_category",
        "case_folding_simple",
        "is_alphabetic",
    }),
    .fields_1 = @as([]const []const u8, &.{
        // ...
    }),
    .fields_2 = @as([]const []const u8, &.{
        // ...
    }),
    // ... `fields_3` to `fields_9`
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
// In `src/build/uucode_config.zig`:

const config = @import("config.zig");

// Use `config.x.zig` for extensions already built into `uucode`:
const config_x = @import("config.x.zig");

const d = config.default;
const wcwidth = config_x.wcwidth;

// Or build your own extension:
const emoji_odd_or_even = config.Extension{
    .inputs = &.{"is_emoji"},
    .compute = &computeEmojiOddOrEven,
    .fields = &.{
        .{ .name = "emoji_odd_or_even", .type = EmojiOddOrEven },
    },
};

fn computeEmojiOddOrEven(cp: u21, data: anytype, backing: anytype, tracking: anytype) void {
    // backing and tracking are only used for slice types
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

// Customize settings to your needs (or use the defaults):
pub const tables = [_]config.Table{
    .{
        // A two stage table can be a tiny bit faster if the data is small. the
        // default `.auto` will try to pick a reasonable value, but the best
        // thing to do is to benchmark with realistic data.
        .stages = .three, // or .two

        // The default `.auto` value will try to decide whether the final data
        // stage struct should be a `packed struct` or a regular Zig `struct`.
        .packing = .unpacked, // or .@"packed"

        .extensions = &.{
            emoji_odd_or_even,
            wcwidth,
        },

        .fields = &.{
            // Don't forget to include the extension fields here:
            emoji_odd_or_even.field("emoji_odd_or_even"),
            wcwidth.field("wcwidth"),

            // See `src/config.zig` for everything that can be overriden.
            // In this example, we're embedding 15 bytes into the `stage3` data,
            // and only names longer that need to use the `backing` slice.
            d.field("name").override(.{
                .embedded_len = 15,
                .max_offset = 986096, // run once to get the correct number
            }),

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
// LSP completion.
uucode.getX(.emoji_odd_or_even, 0x1F34B) // 🍋 == .odd_emoji

// Built-in extensions can still use `get`
uucode.get(.wcwidth, 0x26F5) // ⛵ == 2
```

## Code architecture

The architecture works in a few layers:

* Layer 1 (`src/build/Ucd.zig`): Parses the Unicode Character Database (UCD).
* Layer 2 (`src/build/tables.zig`): Generates table data written to a zig file.
* Layer 3 (`src/root.zig`): Exposes methods to fetch information from the built tables.


## AGENTS.md

The `AGENTS.md` has primarily been useful for an initial pass at parsing the UCD text files, but all agent code has been carefully reviewed, and most code has been written manually.
