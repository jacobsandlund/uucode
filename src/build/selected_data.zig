//! This generates a SelectedData.zig file that defines which fields from FullData
//! should be included in the generated tables.
const std = @import("std");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.skip(); // Skip program name
    const output_path = args_iter.next() orelse @panic("No output file arg!");

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    const writer = out_file.writer();

    try generateSelectedData(writer);
}

fn generateSelectedData(writer: anytype) !void {
    try writer.writeAll(
        \\//! This file is auto-generated. Do not edit.
        \\//! Defines which fields from FullData should be included in the generated tables.
        \\
        \\const data = @import("data");
        \\
        \\pub const SelectedData = struct {
        \\    case_folding_simple: u21 = 0,
        \\};
        \\
    );
}

test "generate selected data" {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try generateSelectedData(fbs.writer());

    const expected =
        \\//! This file is auto-generated. Do not edit.
        \\//! Defines which fields from FullData should be included in the generated tables.
        \\
        \\const data = @import("data");
        \\
        \\pub const SelectedData = struct {
        \\    case_folding_simple: u21 = 0,
        \\};
        \\
    ;

    try std.testing.expectEqualSlices(u8, expected, fbs.getWritten());
}
