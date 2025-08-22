# uucode (Micro/µ Unicode)

TODO: add documentation in this README and in some static docs site.

Check out the [AGENTS.md](./AGENTS.md) for a basic explanation. (I've not actually used agents that much but they're sometimes helpful for easier tasks.)

## Super basic usage

### API

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
        "is_emoji",
    }),
})) |dep| {
    step.root_module.addImport("uucode", dep.module("uucode"));
}
```

#### Advanced configuration

``` zig
// In `build.zig`:
b.dependency("uucode", .{
    .build_config_path = b.path("src/build/uucode_config.zig"),
})

// `src/build/uucode_config.zig`:
const config = @import("config.zig");
const d = config.default;

// See https://github.com/jacobsandlund/uucode.x for community extensions.
//const config_x = @import("config.x.zig");
//const wcwidth = config_x.wcwidth;

fn computeOddEmoji(cp: u21, data: anytype, backing: anytype, tracking: anytype) void {
    _ = backing;
    _ = tracking;
    data.is_odd_emoji = data.is_emoji and cp % 2 == 1;
}

const is_odd_emoji = config.Extension{
    .inputs = &.{"is_emoji"},
    .compute = &computeOddEmoji,
    .fields = &.{
        .{ .name = "is_odd_emoji", .type = bool },
    },
}

pub const tables = [_]config.Table{
    .{
        .extensions = &.{
            is_odd_emoji,
            //wcwidth,
        },
        .fields = &.{
            is_odd_emoji.field("is_odd_emoji"),
            //wcwidth.field("wcwidth"),
            d.field("general_category"),
            d.field("block"),
            d.field("is_emoji_presentation"),
            d.field("case_folding_full"),
            d.field("grapheme_break"),
        },
    },
}
```
