const std = @import("std");

const test_table_configs =
    \\const types = @import("types");
    \\const config = @import("config");
    \\
    \\pub const configs = [_]types.TableConfig{
    \\    .override(&config.default, .{
    \\        .fields = &.{"case_folding_simple"},
    \\    }),
    \\    .override(&config.default, .{
    \\        .fields = &.{"alphabetic","lowercase","uppercase"},
    \\    }),
    \\};
;

const error_configs =
    \\Pass `table-configs` with a string defining the table configs.
;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const table_configs = b.option([]const u8, "table-configs", "Table configs") orelse error_configs;

    // b.addModule with an existing module
    _ = b.modules.put(b.dupe("uucode"), createLibMod(b, target, optimize, table_configs).lib_mod) catch @panic("OOM");

    const t = createLibMod(b, target, optimize, test_table_configs);

    const src_tests = b.addTest(.{
        .root_module = t.lib_mod,
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

pub fn createLibMod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    table_configs: []const u8,
) struct { lib_mod: *std.Build.Module, build_tables_mod: *std.Build.Module } {
    const tables_optimize = switch (optimize) {
        .ReleaseFast => .ReleaseSafe,
        else => optimize,
    };

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
    config_mod.addImport("types", types_mod);

    // Create table_configs file
    const table_configs_step = b.addWriteFiles();
    const table_configs_file = table_configs_step.add("table_configs.zig", table_configs);
    const table_configs_mod = b.createModule(.{
        .root_source_file = table_configs_file,
        .target = target,
        .optimize = optimize,
    });
    table_configs_mod.addImport("types", types_mod);
    table_configs_mod.addImport("config", config_mod);

    // Generate tables.zig with config
    const build_tables_mod = b.createModule(.{
        .root_source_file = b.path("src/build/tables.zig"),
        .target = b.graph.host,
        .optimize = tables_optimize,
        .strip = false,
        .omit_frame_pointer = false,
        .unwind_tables = .sync,
    });
    const build_tables_exe = b.addExecutable(.{
        .name = "tables",
        .root_module = build_tables_mod,
    });
    build_tables_mod.addImport("config", config_mod);
    build_tables_mod.addImport("table_configs", table_configs_mod);
    build_tables_mod.addImport("types", types_mod);
    const run_tables_exe = b.addRunArtifact(build_tables_exe);
    run_tables_exe.stdio = .inherit;
    const tables_out = run_tables_exe.addOutputFileArg("tables.zig");

    const tables_mod = b.createModule(.{
        .root_source_file = tables_out,
        .target = target,
        .optimize = optimize,
    });
    tables_mod.addImport("types", types_mod);
    tables_mod.addImport("config", config_mod);

    lib_mod.addImport("config", config_mod);
    lib_mod.addImport("tables", tables_mod);
    lib_mod.addImport("types", types_mod);

    return .{ .lib_mod = lib_mod, .build_tables_mod = build_tables_mod };
}
