const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tables_optimize = switch (optimize) {
        .ReleaseFast => .ReleaseSafe,
        else => optimize,
    };

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

    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create fields file
    const fields_step = b.addWriteFiles();
    const fields_file = fields_step.add("fields.zig",
        \\pub const fields = [_][]const []const u8{
        \\    &[_][]const u8{"case_folding_simple"},
        \\    &[_][]const u8{"alphabetic","lowercase","uppercase"},
        \\};
    );
    const fields_mod = b.createModule(.{
        .root_source_file = fields_file,
        .target = target,
        .optimize = optimize,
    });

    // Generate tables.zig with selected fields
    const tables_exe = b.addExecutable(.{
        .name = "tables",
        .root_source_file = b.path("src/build/tables.zig"),
        .target = target,
        .optimize = tables_optimize,
    });
    tables_exe.root_module.addImport("types", types_mod);
    tables_exe.root_module.addImport("fields", fields_mod);
    const run_tables_exe = b.addRunArtifact(tables_exe);
    run_tables_exe.stdio = .inherit;
    const tables_out = run_tables_exe.addOutputFileArg("tables.zig");

    const tables_mod = b.createModule(.{
        .root_source_file = tables_out,
        .target = target,
        .optimize = optimize,
    });
    tables_mod.addImport("types", types_mod);

    lib_mod.addImport("tables", tables_mod);
    lib_mod.addImport("types", types_mod);
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
