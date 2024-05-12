const std = @import("std");
const Allocator = std.mem.Allocator;

/// A simple string type that can be used to build up strings.
/// I need this so I won't see allocPrint, bufPrint
/// or a bunch of buffers everywhere in the code lol
///
/// ! Please note that this is a very simple implementation and
/// ! is not suitable for other projects.
pub const String = struct {
    buf: []u8,
    size: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator) String {
        return .{
            .buf = &[_]u8{},
            .size = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: String) void {
        self.allocator.free(self.buf);
    }

    pub fn concat(self: *String, value: []const u8) Allocator.Error!void {
        // Do nothing if the value is empty
        if (value.len == 0) {
            return;
        }

        // Make sure buffer has enough space
        const capacity = self.size + value.len;
        if (capacity > self.buf.len) {
            self.buf = try self.allocator.realloc(self.buf, capacity);
        }

        // Copy the value into the buffer
        var i: usize = 0;
        while (i < value.len) : (i += 1) {
            self.buf[self.size + i] = value[i];
        }

        self.size += value.len;
    }

    pub fn concatAll(self: *String, values: []const []const u8) Allocator.Error!void {
        for (values) |value| {
            try self.concat(value);
        }
    }

    pub fn concatIf(self: *String, condition: bool, value: []const u8) Allocator.Error!void {
        if (condition) try self.concat(value);
    }

    pub fn string(self: *String) []const u8 {
        return self.buf[0..self.size];
    }

    pub fn len(self: *String) usize {
        return self.size;
    }
};
