const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fields = b.option(
        []const []const u8,
        "fields",
        "Fields to build into table for `get` (alias for `fields_0`)",
    );

    const fields_0 = b.option(
        []const []const u8,
        "fields_0",
        "Fields to build into table 0 for `get`",
    );

    const fields_1 = b.option(
        []const []const u8,
        "fields_1",
        "Fields to build into table 1 for `get`",
    );

    const fields_2 = b.option(
        []const []const u8,
        "fields_2",
        "Fields to build into table 2 for `get`",
    );

    const fields_3 = b.option(
        []const []const u8,
        "fields_3",
        "Fields to build into table 3 for `get`",
    );

    const fields_4 = b.option(
        []const []const u8,
        "fields_4",
        "Fields to build into table 4 for `get`",
    );

    const fields_5 = b.option(
        []const []const u8,
        "fields_5",
        "Fields to build into table 5 for `get`",
    );

    const fields_6 = b.option(
        []const []const u8,
        "fields_6",
        "Fields to build into table 6 for `get`",
    );

    const fields_7 = b.option(
        []const []const u8,
        "fields_7",
        "Fields to build into table 7 for `get`",
    );

    const fields_8 = b.option(
        []const []const u8,
        "fields_8",
        "Fields to build into table 8 for `get`",
    );

    const fields_9 = b.option(
        []const []const u8,
        "fields_9",
        "Fields to build into table 9 for `get`",
    );

    const build_log_level = b.option(
        std.log.Level,
        "build_log_level",
        "Log level to use when building tables",
    );

    const build_config_zig_opt = b.option(
        []const u8,
        "build_config.zig",
        "Build config source code",
    );

    const build_config_path_opt = b.option(
        std.Build.LazyPath,
        "build_config_path",
        "Path to uucode_build_config.zig file",
    );

    const tables_path_opt = b.option(
        std.Build.LazyPath,
        "tables_path",
        "Path to built tables source file",
    );

    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Filter for test. Only applies to Zig tests.",
    ) orelse &[0][]const u8{};

    const build_config_path = build_config_path_opt orelse blk: {
        const build_config_zig = build_config_zig_opt orelse buildBuildConfig(
            b.allocator,
            fields orelse fields_0,
            fields_1,
            fields_2,
            fields_3,
            fields_4,
            fields_5,
            fields_6,
            fields_7,
            fields_8,
            fields_9,
            build_log_level,
        );

        break :blk b.addWriteFiles().add("build_config.zig", build_config_zig);
    };

    const mod = createLibMod(
        b,
        target,
        optimize,

        // There's a bug where building tables in ReleaseFast doesn't work,
        // that I'll be investigating in a follow up commit.
        .Debug,
        tables_path_opt,
        build_config_path,
    );

    // b.addModule with an existing module
    _ = b.modules.put(b.allocator, b.dupe("uucode"), mod.lib) catch @panic("OOM");
    _ = b.modules.put(b.allocator, b.dupe("uucode_build_config"), mod.build_config) catch @panic("OOM");
    if (mod.gen_build_config) |btc| {
        _ = b.modules.put(b.allocator, b.dupe("uucode_gen_build_config"), btc) catch @panic("OOM");
    }
    b.addNamedLazyPath("tables.zig", mod.tables_path);

    const test_mod = createLibMod(
        b,
        target,
        optimize,

        // There's a bug where building tables in ReleaseFast doesn't work,
        // that I'll be investigating in a follow up commit.
        .Debug,
        null,
        b.path("src/test/build_config.zig"),
    );

    const src_tests = b.addTest(.{
        .root_module = test_mod.lib,
        .filters = test_filters,
    });

    const generate_tests = b.addTest(.{
        .root_module = test_mod.generate.?,
        .filters = test_filters,
    });

    const build_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("build.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .filters = test_filters,
    });

    const run_src_tests = b.addRunArtifact(src_tests);
    const run_build_tables_tests = b.addRunArtifact(generate_tests);
    const run_build_tests = b.addRunArtifact(build_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_src_tests.step);
    test_step.dependOn(&run_build_tables_tests.step);
    test_step.dependOn(&run_build_tests.step);
}

fn buildBuildConfig(
    allocator: std.mem.Allocator,
    fields_0: ?[]const []const u8,
    fields_1: ?[]const []const u8,
    fields_2: ?[]const []const u8,
    fields_3: ?[]const []const u8,
    fields_4: ?[]const []const u8,
    fields_5: ?[]const []const u8,
    fields_6: ?[]const []const u8,
    fields_7: ?[]const []const u8,
    fields_8: ?[]const []const u8,
    fields_9: ?[]const []const u8,
    build_log_level: ?std.log.Level,
) []const u8 {
    var bytes = std.Io.Writer.Allocating.init(allocator);
    defer bytes.deinit();
    const writer = &bytes.writer;

    if (fields_0 == null) {
        return bytes.toOwnedSlice() catch @panic("OOM");
    }

    writer.writeAll(
        \\const config = @import("config.zig");
        \\
        \\pub const fields = config.fields;
        \\pub const build_components = config.build_components;
        \\pub const get_components = config.get_components;
        \\
        \\
    ) catch @panic("OOM");

    if (build_log_level) |level| {
        writer.print(
            \\pub const log_level = .{s};
            \\
            \\
        , .{@tagName(level)}) catch @panic("OOM");
    }

    writer.writeAll(
        \\pub const tables: []const config.Table = &.{
        \\
    ) catch @panic("OOM");

    const fields_lists = [_]?[]const []const u8{
        fields_0,
        fields_1,
        fields_2,
        fields_3,
        fields_4,
        fields_5,
        fields_6,
        fields_7,
        fields_8,
        fields_9,
    };

    for (fields_lists) |fields_opt| {
        if (fields_opt) |fields| {
            writer.writeAll(
                \\    .{
                \\        .fields = &.{
                \\
            ) catch @panic("OOM");

            for (fields) |f| {
                writer.print("            \"{s}\",\n", .{f}) catch @panic("OOM");
            }

            writer.writeAll(
                \\        },
                \\     },
                \\
            ) catch @panic("OOM");
        } else {
            break;
        }
    }

    writer.writeAll(
        \\};
        \\
    ) catch @panic("OOM");

    return bytes.toOwnedSlice() catch @panic("OOM");
}

fn generateTables(
    b: *std.Build,
    build_config_path: std.Build.LazyPath,
    generate_optimize: std.builtin.OptimizeMode,
) struct {
    generate: *std.Build.Module,
    build_config: *std.Build.Module,
    tables: std.Build.LazyPath,
} {
    const target = b.graph.host;

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = generate_optimize,
    });

    const storage_mod = b.createModule(.{
        .root_source_file = b.path("src/storage.zig"),
        .target = target,
        .optimize = generate_optimize,
    });

    config_mod.addImport("storage.zig", storage_mod);
    storage_mod.addImport("config.zig", config_mod);

    // Create build_config
    const build_config_mod = b.createModule(.{
        .root_source_file = build_config_path,
        .target = target,
        .optimize = generate_optimize,
    });
    build_config_mod.addImport("config.zig", config_mod);
    build_config_mod.addImport("storage.zig", storage_mod);

    const gen_mod = b.createModule(.{
        .root_source_file = b.path("src/generate.zig"),
        .target = b.graph.host,
        .optimize = generate_optimize,
    });
    const gen_exe = b.addExecutable(.{
        .name = "uucode_generate",
        .root_module = gen_mod,

        // Zig's x86 backend is segfaulting, so we choose the LLVM backend always.
        .use_llvm = true,
    });

    gen_mod.addImport("config.zig", config_mod);
    gen_mod.addImport("storage.zig", storage_mod);
    gen_mod.addImport("build_config", build_config_mod);
    const run_gen_exe = b.addRunArtifact(gen_exe);
    run_gen_exe.setCwd(b.path(""));
    const tables_path = run_gen_exe.addOutputFileArg("tables.zig");

    return .{
        .tables = tables_path,
        .generate = gen_mod,
        .build_config = build_config_mod,
    };
}

fn createLibMod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    generate_optimize: std.builtin.OptimizeMode,
    tables_path_opt: ?std.Build.LazyPath,
    build_config_path: std.Build.LazyPath,
) struct {
    lib: *std.Build.Module,
    build_config: *std.Build.Module,
    gen_build_config: ?*std.Build.Module,
    generate: ?*std.Build.Module,
    tables_path: std.Build.LazyPath,
} {
    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = optimize,
    });
    config_mod.addImport("types.zig", types_mod);

    const storage_mod = b.createModule(.{
        .root_source_file = b.path("src/storage.zig"),
        .target = target,
        .optimize = optimize,
    });

    config_mod.addImport("storage.zig", storage_mod);
    storage_mod.addImport("config.zig", config_mod);

    const build_config_mod = b.createModule(.{
        .root_source_file = build_config_path,
        .target = target,
    });
    build_config_mod.addImport("config.zig", config_mod);
    build_config_mod.addImport("storage.zig", storage_mod);

    var generate: ?*std.Build.Module = null;
    var gen_build_config: ?*std.Build.Module = null;
    const tables_path = tables_path_opt orelse blk: {
        const t = generateTables(b, build_config_path, generate_optimize);
        generate = t.generate;
        gen_build_config = t.build_config;
        break :blk t.tables;
    };

    const tables_mod = b.createModule(.{
        .root_source_file = tables_path,
        .target = target,
        .optimize = optimize,
    });
    tables_mod.addImport("config.zig", config_mod);
    tables_mod.addImport("storage.zig", storage_mod);
    tables_mod.addImport("build_config", build_config_mod);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("types.zig", types_mod);
    lib_mod.addImport("config.zig", config_mod);
    lib_mod.addImport("tables", tables_mod);

    return .{
        .lib = lib_mod,
        .build_config = build_config_mod,
        .generate = generate,
        .gen_build_config = gen_build_config,
        .tables_path = tables_path,
    };
}

test "simple build config with just fields/fields_0" {
    const build_config = buildBuildConfig(
        std.testing.allocator,
        &.{ "name", "is_emoji", "bidi_class" },
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        .debug,
    );
    defer std.testing.allocator.free(build_config);

    errdefer std.debug.print("build_config: {s}", .{build_config});

    const expected =
        \\const config = @import("config.zig");
        \\
        \\pub const fields = config.fields;
        \\pub const build_components = config.build_components;
        \\pub const get_components = config.get_components;
        \\
        \\pub const log_level = .debug;
        \\
        \\pub const tables: []const config.Table = &.{
        \\    .{
        \\        .fields = &.{
        \\            "name",
        \\            "is_emoji",
        \\            "bidi_class",
        \\        },
        \\     },
        \\};
        \\
    ;

    try std.testing.expect(std.mem.eql(u8, build_config, expected));
}

test "complex build config with all fields_0 through fields_9" {
    const build_config = buildBuildConfig(
        std.testing.allocator,
        &.{ "name", "field_0a", "field_0b" },
        &.{ "general_category", "field_1" },
        &.{ "decomposition_type", "field_2a", "field_2b" },
        &.{ "numeric_type", "field_3" },
        &.{ "unicode_1_name", "field_4a", "field_4b" },
        &.{ "simple_lowercase_mapping", "field_5" },
        &.{ "case_folding_simple", "field_6" },
        &.{ "special_lowercase_mapping", "field_7a", "field_7b", "field_7c" },
        &.{ "lowercase_mapping", "field_8" },
        &.{ "uppercase_mapping", "field_9" },
        .info,
    );
    defer std.testing.allocator.free(build_config);

    errdefer std.debug.print("build_config: {s}", .{build_config});

    const substrings = [_][]const u8{
        "pub const log_level = .info;",
        "pub const tables: []const config.Table = &.{",
        ".fields =",
        "name",
        "field_0a",
        "field_0b",
        ".fields =",
        "general_category",
        "field_1",
        ".fields =",
        "decomposition_type",
        "field_2a",
        "field_2b",
        ".fields =",
        "numeric_type",
        "field_3",
        ".fields =",
        "unicode_1_name",
        "field_4a",
        "field_4b",
        ".fields =",
        "simple_lowercase_mapping",
        "field_5",
        ".fields =",
        "case_folding_simple",
        "field_6",
        ".fields =",
        "special_lowercase_mapping",
        "field_7a",
        "field_7b",
        "field_7c",
        ".fields =",
        "lowercase_mapping",
        "field_8",
        ".fields =",
        "uppercase_mapping",
        "field_9",
        "};",
    };

    var i: usize = 0;

    for (substrings) |substring| {
        const foundI = std.mem.indexOfPos(u8, build_config, i, substring);
        try std.testing.expect(foundI != null);
        try std.testing.expect(foundI.? > i);
        i = foundI.?;
    }
}
