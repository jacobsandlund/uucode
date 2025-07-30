const std = @import("std");
const types = @import("types.zig");

pub const max_code_point: u21 = 0x10FFFF;
pub const code_point_range_end: u21 = max_code_point + 1;

pub const updating_ucd = true;

pub const all_fields = brk: {
    const full_fields = @typeInfo(types.FullData).@"struct".fields;
    var fields: [full_fields.len][]const u8 = undefined;
    for (full_fields, 0..) |field, i| {
        fields[i] = field.name;
    }

    break :brk fields;
};

pub const default = types.TableConfig{
    .stages = .auto,
    .fields = fields: {
        var f = std.BoundedArray(types.TableConfig.Field, all_fields.len){};
        f.appendSliceAssumeCapacity(&.{
            .{ .offset_len = .{
                .name = "name",
                .max_len = 88,
                .max_offset = 1031029,
                .embedded_len = 2,
            } },
            .{ .offset_len = .{
                .name = "decomposition_mapping",
                .max_len = 18,
                .max_offset = 6454,
                .embedded_len = 0,
            } },
            .{ .offset_len = .{
                .name = "numeric_value_numeric",
                .max_len = 13,
                .max_offset = 503,
                .embedded_len = 1,
            } },
            .{ .offset_len = .{
                .name = "unicode_1_name",
                .max_len = 55,
                .max_offset = 49956,
                .embedded_len = 0,
            } },
            .{ .offset_len = .{
                .name = "case_folding_full",
                .max_len = 3,
                .max_offset = 160,
                .embedded_len = 0,
            } },
        });

        break :fields f;
    },
};

pub const updating_ucd_config = default.override(.{
    .fields = .{
        .{
            .name = "name",
            .max_len = 200,
            .max_offset = 2_000_000,
            .embedded_len = 0,
        },
        .{
            .name = "decomposition_mapping",
            .max_len = 40,
            .max_offset = 16_000,
            .embedded_len = 0,
        },
        .{
            .name = "numeric_value_numeric",
            .max_len = 30,
            .max_offset = 4000,
            .embedded_len = 0,
        },
        .{
            .name = "unicode_1_name",
            .max_len = 120,
            .max_offset = 100_000,
            .embedded_len = 0,
        },
        .{
            .name = "case_folding_full",
            .max_len = 9,
            .max_offset = 500,
            .embedded_len = 0,
        },
    },
});
