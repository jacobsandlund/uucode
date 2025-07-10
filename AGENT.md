# uucode (Micro/µ Unicode)

## Project Overview

This library intends to provide a minimal set of unicode functionality to enable Ghostty and similar projects.

The architecture works in a few layers:

* Layer 1 (@src/build/ucd.zig): Low-level parsing of the Unicode Character Database (`upd`).
* Layer 2 (@src/build/tables.zig): Grouping of the `ucd` by key type (e.g. code point), pointing to customizable information in the values, and generating zig files for these tables.
* Layer 3 (@src/root.zig): Exposing API methods to look up information from the built tables.

## Build & Commands

* Build with: `zig build`
* Test with: `zig build test`
* Format code with: `zig fmt`

## Code Style

Follow Zig standard conventions, but keep imports at the top.

Prefer self-documenting code to comments, but add detailed comments for anything that needs explanation.

## Testing

Add `test "<description here>"` blocks directly below code that it is testing, with more blocks at the bottom of module for testing the entire module.
