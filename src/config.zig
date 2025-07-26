const types = @import("types");

pub const updating_ucd = false;

pub const all_fields = brk: {
    const full_fields = @typeInfo(types.FullData).@"struct".fields;
    var fields: [full_fields.len][]const u8 = undefined;
    for (full_fields, 0..) |field, i| {
        fields[i] = field.name;
    }

    break :brk fields;
};

pub const default = types.TableConfig{
    .fields = &[_][]const u8{},
    .name = .{
        .max_len = 88,
        .max_offset = 1031029,
        .embedded_len = 2,
    },
    .decomposition_mapping = .{
        .max_len = 18,
        .max_offset = 6454,
        .embedded_len = 0,
    },
    .numeric_value_numeric = .{
        .max_len = 13,
        .max_offset = 503,
        .embedded_len = 1,
    },
    .unicode_1_name = .{
        .max_len = 55,
        .max_offset = 49956,
        .embedded_len = 0,
    },
    .case_folding_full = .{
        .max_len = 3,
        .max_offset = 160,
        .embedded_len = 0,
    },
};

pub const updating_ucd_config = types.TableConfig{
    .fields = &all_fields,
    .name = .{
        .max_len = 200,
        .max_offset = 2_000_000,
        .embedded_len = 0,
    },
    .decomposition_mapping = .{
        .max_len = 40,
        .max_offset = 16_000,
        .embedded_len = 0,
    },
    .numeric_value_numeric = .{
        .max_len = 30,
        .max_offset = 4000,
        .embedded_len = 0,
    },
    .unicode_1_name = .{
        .max_len = 120,
        .max_offset = 100_000,
        .embedded_len = 0,
    },
    .case_folding_full = .{
        .max_len = 9,
        .max_offset = 500,
        .embedded_len = 0,
    },
};
