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

    const tables_path = tables_path_opt orelse tables_blk: {
        const build_config_path = build_config_path_opt orelse path_blk: {
            const build_config_zig = build_config_zig_opt orelse config_blk: {
                var bytes = std.ArrayList(u8).init(b.allocator);
                defer bytes.deinit();
                const writer = bytes.writer();

                writer.writeAll(
                    \\const config = @import("config.zig");
                    \\
                    \\pub const tables = config.tables(.{
                    \\    .{
                    \\        .fields = .{
                    \\
                ) catch @panic("OOM");

                if (table_0_fields) |fields| {
                    for (fields) |f| {
                        writer.print("            \"{s}\",\n", .{f}) catch @panic("OOM");
                    }
                } else {
                    writer.writeAll("Specify either `table_0_fields`, `build_config.zig`, `build_config_path`, or `tables.zig`\n") catch @panic("OOM");
                }

                if (table_1_fields) |fields| {
                    writer.writeAll(
                        \\         },
                        \\     },
                        \\    .{
                        \\        .fields = .{
                    ) catch @panic("OOM");

                    for (fields) |f| {
                        writer.print("            \"{s}\",\n", .{f}) catch @panic("OOM");
                    }
                }

                writer.writeAll(
                    \\         },
                    \\     },
                    \\});
                    \\
                ) catch @panic("OOM");

                break :config_blk bytes.toOwnedSlice() catch @panic("OOM");
            };

            break :path_blk b.addWriteFiles().add("build_config.zig", build_config_zig);
        };
        break :tables_blk buildTables(b, build_config_path).tables_path;
    };

    b.addNamedLazyPath("tables.zig", tables_path);

    const lib = createLibMod(b, target, optimize, tables_path);

    // b.addModule with an existing module
    _ = b.modules.put(b.dupe("uucode"), lib) catch @panic("OOM");

    const test_build_config_path = b.addWriteFiles().add("test_build_config.zig", test_build_config_zig);
    const t = buildTables(b, test_build_config_path);
    const test_lib_mod = createLibMod(b, target, optimize, t.tables_path);

    const src_tests = b.addTest(.{
        .root_module = test_lib_mod,
    });

    const build_tests = b.addTest(.{
        .root_module = t.build_tables_mod,
    });

    const run_src_tests = b.addRunArtifact(src_tests);
    const run_build_tests = b.addRunArtifact(build_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_src_tests.step);
    test_step.dependOn(&run_build_tests.step);
}

const test_build_config_zig =
    \\const config = @import("config.zig");
    \\
    \\pub const tables = config.tables(.{
    \\    .{
    \\        .fields = .{ "case_folding_simple", .{ .name = "name", .embedded_len = 15 } },
    \\    },
    \\    .{
    \\        .fields = .{ "is_alphabetic", "is_lowercase", "is_uppercase" },
    \\    },
    \\});
    \\
;

fn createLibMod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    tables_path: std.Build.LazyPath,
) *std.Build.Module {
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

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

    lib_mod.addImport("config.zig", config_mod);
    lib_mod.addImport("tables", tables_mod);
    lib_mod.addImport("types.zig", types_mod);
    lib_mod.addImport("get.zig", get_mod);

    return lib_mod;
}

fn buildTables(
    b: *std.Build,
    build_config_path: std.Build.LazyPath,
) struct { build_tables_mod: *std.Build.Module, tables_path: std.Build.LazyPath } {
    const target = b.graph.host;

    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
    });

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
    });
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

    return .{ .build_tables_mod = build_tables_mod, .tables_path = tables_path };
}
