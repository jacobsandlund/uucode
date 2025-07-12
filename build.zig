const std = @import("std");
const tables = @import("src/build/tables.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tables_exe = b.addExecutable(.{
        .name = "tables",
        .root_source_file = b.path("src/build_main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tables_exe = b.addRunArtifact(tables_exe);
    run_tables_exe.stdio = .inherit;
    const tables_out = run_tables_exe.addOutputFileArg("tables.zig");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "uucode",
        .root_module = lib_mod,
    });

    const data_mod = b.createModule(.{
        .root_source_file = b.path("src/data.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tables_mod = b.createModule(.{
        .root_source_file = tables_out,
        .target = target,
        .optimize = optimize,
    });
    tables_mod.addImport("data", data_mod);

    lib_mod.addImport("tables", tables_mod);
    lib_mod.addImport("data", data_mod);
    tables_out.addStepDependencies(&lib.step);

    b.installArtifact(lib);

    const src_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const build_tests = b.addTest(.{
        .root_module = tables_exe.root_module,
    });

    const run_src_tests = b.addRunArtifact(src_tests);
    const run_build_tests = b.addRunArtifact(build_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_src_tests.step);
    test_step.dependOn(&run_build_tests.step);
}
