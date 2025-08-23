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

    const tables_path_opt = b.option(std.Build.LazyPath, "tables.zig", "Built tables source file");

    const build_config_path = build_config_path_opt orelse path_blk: {
        const build_config_zig = build_config_zig_opt orelse config_blk: {
            var bytes = std.ArrayList(u8).init(b.allocator);
            defer bytes.deinit();
            const writer = bytes.writer();

            if (table_0_fields == null) {
                break :config_blk bytes.toOwnedSlice() catch @panic("OOM");
            }

            writer.writeAll(
                \\const config = @import("config.zig");
                \\const d = config.default;
                \\
                \\pub const tables = [_]config.Table{
                \\    .{
                \\        .fields = &.{
                \\
            ) catch @panic("OOM");

            for (table_0_fields.?) |f| {
                writer.print("            d.field(\"{s}\"),\n", .{f}) catch @panic("OOM");
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

    const mod = createLibMod(b, target, optimize, tables_path_opt, build_config_path);

    // b.addModule with an existing module
    _ = b.modules.put(b.dupe("uucode"), mod.lib) catch @panic("OOM");
    b.addNamedLazyPath("tables.zig", mod.tables_path);

    const test_mod = createLibMod(b, target, optimize, null, b.path("src/build/test_build_config.zig"));

    const src_tests = b.addTest(.{
        .root_module = test_mod.lib,
    });

    const build_tests = b.addTest(.{
        .root_module = test_mod.build_tables.?,
    });

    const run_src_tests = b.addRunArtifact(src_tests);
    const run_build_tests = b.addRunArtifact(build_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_src_tests.step);
    test_step.dependOn(&run_build_tests.step);
}

fn createLibMod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    tables_path_opt: ?std.Build.LazyPath,
    build_config_path: std.Build.LazyPath,
) struct {
    lib: *std.Build.Module,
    build_tables: ?*std.Build.Module,
    tables_path: std.Build.LazyPath,
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

    const config_x_mod = b.createModule(.{
        .root_source_file = b.path("src/x/config.x.zig"),
        .target = target,
        .optimize = optimize,
    });

    const types_x_mod = b.createModule(.{
        .root_source_file = b.path("src/x/types.x.zig"),
        .target = target,
        .optimize = optimize,
    });
    types_x_mod.addImport("config.x.zig", config_x_mod);
    config_x_mod.addImport("types.x.zig", types_x_mod);
    config_x_mod.addImport("types.zig", types_mod);
    config_x_mod.addImport("config.zig", config_mod);

    const build_config_mod = b.createModule(.{
        .root_source_file = build_config_path,
        .target = target,
    });
    build_config_mod.addImport("types.zig", types_mod);
    build_config_mod.addImport("config.zig", config_mod);
    build_config_mod.addImport("types.x.zig", types_x_mod);
    build_config_mod.addImport("config.x.zig", config_x_mod);

    var build_tables: ?*std.Build.Module = null;
    const tables_path = tables_path_opt orelse blk: {
        const t = buildTables(b, build_config_path);
        build_tables = t.build_tables;
        break :blk t.tables;
    };

    const tables_mod = b.createModule(.{
        .root_source_file = tables_path,
        .target = target,
        .optimize = optimize,
    });
    tables_mod.addImport("types.zig", types_mod);
    tables_mod.addImport("types.x.zig", types_x_mod);
    tables_mod.addImport("config.zig", config_mod);
    tables_mod.addImport("build_config", build_config_mod);

    const get_mod = b.createModule(.{
        .root_source_file = b.path("src/get.zig"),
        .target = target,
        .optimize = optimize,
    });
    get_mod.addImport("types.zig", types_mod);
    get_mod.addImport("tables", tables_mod);
    types_mod.addImport("get.zig", get_mod);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("types.zig", types_mod);
    lib_mod.addImport("config.zig", config_mod);
    lib_mod.addImport("types.x.zig", types_x_mod);
    lib_mod.addImport("tables", tables_mod);
    lib_mod.addImport("get.zig", get_mod);

    return .{
        .lib = lib_mod,
        .build_tables = build_tables,
        .tables_path = tables_path,
    };
}

fn buildTables(
    b: *std.Build,
    build_config_path: std.Build.LazyPath,
) struct {
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

    const config_x_mod = b.createModule(.{
        .root_source_file = b.path("src/x/config.x.zig"),
        .target = target,
    });

    const types_x_mod = b.createModule(.{
        .root_source_file = b.path("src/x/types.x.zig"),
        .target = target,
    });
    types_x_mod.addImport("config.x.zig", config_x_mod);
    config_x_mod.addImport("types.x.zig", types_x_mod);
    config_x_mod.addImport("types.zig", types_mod);
    config_x_mod.addImport("config.zig", config_mod);

    // Create build_config
    const build_config_mod = b.createModule(.{
        .root_source_file = build_config_path,
        .target = target,
    });
    build_config_mod.addImport("types.zig", types_mod);
    build_config_mod.addImport("config.zig", config_mod);
    build_config_mod.addImport("types.x.zig", types_x_mod);
    build_config_mod.addImport("config.x.zig", config_x_mod);

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
        .tables = tables_path,
        .build_tables = build_tables_mod,
    };
}
