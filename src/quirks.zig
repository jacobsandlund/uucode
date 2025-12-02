//! cpv: track https://github.com/ghostty-org/ghostty/blob/5714ed07a1012573261b7b7e3ed2add9c1504496/src/quirks.zig#L1-L7
//! Inspired by WebKit's quirks.cpp[1], this file centralizes all our
//! sad environment-specific hacks that we have to do to make things work.
//! This is a last resort; if we can find a general solution to a problem,
//! we of course prefer that, but sometimes other software, fonts, etc. are
//! just broken or weird and we have to work around it.
//!
//! [1]: https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/Quirks.cpp
// cpv: end

/// cpv: track https://github.com/ghostty-org/ghostty/blob/5714ed07a1012573261b7b7e3ed2add9c1504496/src/quirks.zig#L31-L46
/// We use our own assert function instead of `std.debug.assert`.
///
/// The only difference between this and the one in
/// the stdlib is that this version is marked inline.
///
/// The reason for this is that, despite the promises of the doc comment
/// on the stdlib function, the function call to `std.debug.assert` isn't
/// always optimized away in `ReleaseFast` mode, at least in Zig 0.15.2.
///
/// In the majority of places, the overhead from calling an empty function
/// is negligible, but we have some asserts inside tight loops and hotpaths
/// that cause significant overhead (as much as 15-20%) when they don't get
/// optimized out.
pub inline fn inlineAssert(ok: bool) void {
    if (!ok) unreachable;
}
// cpv: end
