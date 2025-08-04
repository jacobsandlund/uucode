const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const table_0_fields = b.option(
        []const []const u8,
        "table_0_fields",
        "Fields for table 0",
    );

    const table_1_fields = b.option(
        []const []const u8,
        "table_1_fields",
        "Fields for table 1",
    );

    const build_config_zig_opt = b.option(
        []const u8,
        "build_config.zig",
        "Build config source code",
    );

    const build_config_path_opt = b.option(
        std.Build.LazyPath,
        "build_config_path",
        "Path to build config zig file",
    );

    const x_root_zig = b.option(
        []const u8,
        "x_root.zig",
        "Source code for `uucode.x` (extension API)",
    ) orelse "";

    const x_root_path = b.option(
        std.Build.LazyPath,
        "x_root_path",
        "Path to `uucode.x` (extension API) source code",
    ) orelse b.addWriteFiles().add("x_root.zig", x_root_zig);

    const tables_path_opt = b.option(std.Build.LazyPath, "tables.zig", "Built tables source file");

    const tables_path = tables_path_opt orelse tables_blk: {
        const build_config_path = build_config_path_opt orelse path_blk: {
            const build_config_zig = build_config_zig_opt orelse config_blk: {
                var bytes = std.ArrayList(u8).init(b.allocator);
                defer bytes.deinit();
                const writer = bytes.writer();

                writer.writeAll(
                    \\const config = @import("config.zig");
                    \\const d = config.default;
                    \\
                    \\pub const tables = [_]config.Table{
                    \\    .{
                    \\        .fields = &.{
                    \\
                ) catch @panic("OOM");

                if (table_0_fields) |fields| {
                    for (fields) |f| {
                        writer.print("            d.field(\"{s}\"),\n", .{f}) catch @panic("OOM");
                    }
                } else {
                    writer.writeAll("Specify either `table_0_fields`, `build_config.zig`, `build_config_path`, or `tables.zig`\n") catch @panic("OOM");
                }

                if (table_1_fields) |fields| {
                    writer.writeAll(
                        \\         },
                        \\     },
                        \\    .{
                        \\        .fields = &.{
                    ) catch @panic("OOM");

                    for (fields) |f| {
                        writer.print("            d.field(\"{s}\"),\n", .{f}) catch @panic("OOM");
                    }
                }

                writer.writeAll(
                    \\         },
                    \\     },
                    \\};
                    \\
                ) catch @panic("OOM");

                break :config_blk bytes.toOwnedSlice() catch @panic("OOM");
            };

            break :path_blk b.addWriteFiles().add("build_config.zig", build_config_zig);
        };

        const t = buildTables(b, build_config_path);

        // b.addModule with an existing module
        _ = b.modules.put(b.dupe("build_config"), t.build_config) catch @panic("OOM");
        _ = b.modules.put(b.dupe("config.zig"), t.config) catch @panic("OOM");

        break :tables_blk t.tables;
    };

    b.addNamedLazyPath("tables.zig", tables_path);

    const mod = createLibMod(b, target, optimize, tables_path, x_root_path);

    // b.addModule with an existing module
    _ = b.modules.put(b.dupe("uucode"), mod.lib) catch @panic("OOM");
    _ = b.modules.put(b.dupe("x"), mod.x) catch @panic("OOM");
    _ = b.modules.put(b.dupe("get.zig"), mod.get) catch @panic("OOM");

    const test_build_config_path = b.addWriteFiles().add("test_build_config.zig", test_build_config_zig);
    const test_x_root_path = b.addWriteFiles().add("test_x_root.zig", test_x_root_zig);
    const t = buildTables(b, test_build_config_path);
    const test_mod = createLibMod(b, target, optimize, t.tables, test_x_root_path);

    const src_tests = b.addTest(.{
        .root_module = test_mod.lib,
    });

    const build_tests = b.addTest(.{
        .root_module = t.build_tables,
    });

    const run_src_tests = b.addRunArtifact(src_tests);
    const run_build_tests = b.addRunArtifact(build_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_src_tests.step);
    test_step.dependOn(&run_build_tests.step);
}

const test_build_config_zig =
    \\const config = @import("config.zig");
    \\const d = config.default;
    \\
    \\fn computeFoo(cp: u21, data: anytype) void {
    \\    _ = cp;
    \\    const foo: u8 = switch (data.grapheme_break) {
    \\        .other => 0,
    \\        .control => 3,
    \\        else => 10,
    \\    };
    \\
    \\    data.foo = foo;
    \\}
    \\
    \\const x = config.Extension{
    \\    .inputs = &.{"grapheme_break"},
    \\    .compute = &computeFoo,
    \\    .fields = &.{.extension("foo", u8)},
    \\};
    \\
    \\pub const tables = [_]config.Table{
    \\    .{
    \\        .stages = .auto,
    \\        .extensions = &.{x},
    \\        .fields = &.{
    \\            x.field("foo"),
    \\            d.field("case_folding_simple"),
    \\            d.field("name").override(.{
    \\                .embedded_len = 15,
    \\                .max_offset = 986664,
    \\            }),
    \\         },
    \\    },
    \\    .{
    \\        .stages = .auto,
    \\        .extensions = &.{},
    \\        .fields = &.{
    \\            d.field("is_alphabetic"),
    \\            d.field("is_lowercase"),
    \\            d.field("is_uppercase"),
    \\         },
    \\    },
    \\};
    \\
;

const test_x_root_zig =
    \\const get = @import("get.zig");
    \\
    \\pub fn foo(cp: u21) u8 {
    \\    const table = comptime get.tableFor("foo");
    \\    return get.data(table, cp).foo;
    \\}
    \\
;

fn createLibMod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    tables_path: std.Build.LazyPath,
    x_root_path: std.Build.LazyPath,
) struct {
    lib: *std.Build.Module,
    get: *std.Build.Module,
    x: *std.Build.Module,
} {
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = optimize,
    });

    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
        .optimize = optimize,
    });
    types_mod.addImport("config.zig", config_mod);
    config_mod.addImport("types.zig", types_mod);

    const tables_mod = b.createModule(.{
        .root_source_file = tables_path,
        .target = target,
        .optimize = optimize,
    });
    tables_mod.addImport("types.zig", types_mod);
    tables_mod.addImport("config.zig", config_mod);

    const get_mod = b.createModule(.{
        .root_source_file = b.path("src/get.zig"),
        .target = target,
        .optimize = optimize,
    });
    get_mod.addImport("types.zig", types_mod);
    get_mod.addImport("tables", tables_mod);
    types_mod.addImport("get.zig", get_mod);

    const x_mod = b.createModule(.{
        .root_source_file = x_root_path,
        .target = target,
        .optimize = optimize,
    });
    x_mod.addImport("get.zig", get_mod);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("x", x_mod);
    lib_mod.addImport("config.zig", config_mod);
    lib_mod.addImport("tables", tables_mod);
    lib_mod.addImport("types.zig", types_mod);
    lib_mod.addImport("get.zig", get_mod);

    return .{
        .lib = lib_mod,
        .get = get_mod,
        .x = x_mod,
    };
}

fn buildTables(
    b: *std.Build,
    build_config_path: std.Build.LazyPath,
) struct {
    config: *std.Build.Module,
    build_config: *std.Build.Module,
    build_tables: *std.Build.Module,
    tables: std.Build.LazyPath,
} {
    const target = b.graph.host;

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
    });

    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
    });
    types_mod.addImport("config.zig", config_mod);
    config_mod.addImport("types.zig", types_mod);

    // Create build_config
    const build_config_mod = b.createModule(.{
        .root_source_file = build_config_path,
        .target = target,
    });
    build_config_mod.addImport("types.zig", types_mod);
    build_config_mod.addImport("config.zig", config_mod);

    // Generate tables.zig with build_config
    const build_tables_mod = b.createModule(.{
        .root_source_file = b.path("src/build/tables.zig"),
        .target = b.graph.host,
    });
    const build_tables_exe = b.addExecutable(.{
        .name = "uucode_build_tables",
        .root_module = build_tables_mod,
    });
    build_tables_mod.addImport("config.zig", config_mod);
    build_tables_mod.addImport("build_config", build_config_mod);
    build_tables_mod.addImport("types.zig", types_mod);
    const run_build_tables_exe = b.addRunArtifact(build_tables_exe);
    const tables_path = run_build_tables_exe.addOutputFileArg("tables.zig");

    return .{
        .config = config_mod,
        .build_config = build_config_mod,
        .build_tables = build_tables_mod,
        .tables = tables_path,
    };
}
