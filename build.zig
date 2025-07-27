const std = @import("std");

const test_table_configs =
    \\const types = @import("types.zig");
    \\const config = @import("config.zig");
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
    const table_data_opt = b.option(std.Build.LazyPath, "table-data", "Built table data");

    const table_data_src = table_data_opt orelse buildTableData(b, table_configs);
    const lib = createLibMod(b, target, optimize, table_data_src);

    // b.addModule with an existing module
    _ = b.modules.put(b.dupe("uucode"), lib) catch @panic("OOM");

    const t = buildTableDataWithMod(b, test_table_configs);
    const test_lib_mod = createLibMod(b, target, optimize, t.table_data_src);

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

fn createLibMod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    table_data_src: std.Build.LazyPath,
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

    const table_data_mod = b.createModule(.{
        .root_source_file = table_data_src,
        .target = target,
        .optimize = optimize,
    });
    table_data_mod.addImport("types.zig", types_mod);
    table_data_mod.addImport("config.zig", config_mod);

    lib_mod.addImport("config.zig", config_mod);
    lib_mod.addImport("table_data", table_data_mod);
    lib_mod.addImport("types.zig", types_mod);

    return lib_mod;
}

fn buildTableDataWithMod(
    b: *std.Build,
    table_configs: []const u8,
) struct { build_tables_mod: *std.Build.Module, table_data_src: std.Build.LazyPath } {
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

    // Create table_configs
    const table_configs_step = b.addWriteFiles();
    const table_configs_file = table_configs_step.add("table_configs.zig", table_configs);
    const table_configs_mod = b.createModule(.{
        .root_source_file = table_configs_file,
        .target = target,
    });
    table_configs_mod.addImport("types.zig", types_mod);
    table_configs_mod.addImport("config.zig", config_mod);

    // Generate table_data.zig with table_configs
    const build_tables_mod = b.createModule(.{
        .root_source_file = b.path("src/build/tables.zig"),
        .target = b.graph.host,
    });
    const build_tables_exe = b.addExecutable(.{
        .name = "uucode_tables",
        .root_module = build_tables_mod,
    });
    build_tables_mod.addImport("config.zig", config_mod);
    build_tables_mod.addImport("table_configs", table_configs_mod);
    build_tables_mod.addImport("types.zig", types_mod);
    const run_tables_exe = b.addRunArtifact(build_tables_exe);
    const table_data_src = run_tables_exe.addOutputFileArg("table_data.zig");

    return .{ .build_tables_mod = build_tables_mod, .table_data_src = table_data_src };
}

pub fn buildTableData(
    b: *std.Build,
    table_configs: []const u8,
) std.Build.LazyPath {
    return buildTableDataWithMod(b, table_configs).table_data_src;
}
