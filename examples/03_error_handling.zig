const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // The explanation for all these basic components can be found in
    // the `01_basic_fetch.zig` file. Do take a look at it if you haven't!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var client = try ipinfo.Client.init(gpa.allocator(), .{});
    defer client.deinit();

    // Passing an invalid IP address just for this example
    // but please do not copy this in your code.
    const res = try client.getIPInfo(.{ .ip_address = "invalid" });
    defer res.deinit();

    switch (res.err) {
        // Handle the failed case
        .Failed => |err| {
            std.debug.print("Failed with error code {d}\n", .{@intFromEnum(err.status)});
            std.debug.print("Error title: {s}\n", .{err.title});
            std.debug.print("Error message: {s}\n", .{err.message});
        },
        // It should never reach here because we have an invalid input
        else => unreachable,
    }
}
