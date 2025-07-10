const ucd = @import("ucd.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
    @import("std").testing.refAllDeclsRecursive(ucd);
}
