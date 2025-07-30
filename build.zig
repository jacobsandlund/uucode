const std = @import("std");

const error_build_config_zig =
    \\TODO: eliminate this and craft a `build_config.zig` from options
;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const build_config_fields0 = b.option(
    //    []const []const u8,
    //    "table_0_fields",
    //    "Build config source code",
    //) orelse error_build_config_zig;

    const build_config_zig = b.option(
        []const u8,
        "build_config.zig",
        "Build config source code",
    ) orelse error_build_config_zig;

    const build_config_path = b.option(
        std.Build.LazyPath,
        "build_config_path",
        "Path to build config zig file",
    ) orelse b.addWriteFiles().add("build_config.zig", build_config_zig);

    const tables_path_opt = b.option(std.Build.LazyPath, "tables.zig", "Built tables source file");

    const tables_path = tables_path_opt orelse buildTables(b, build_config_path).tables_path;
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
    \\        .fields = .{"case_folding_simple", "name"},
    \\    },
    \\    .{
    \\        .fields = .{"is_alphabetic", "is_lowercase", "is_uppercase"},
    \\    },
    \\});
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
