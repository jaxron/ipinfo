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
    const res = try client.basic.getIPInfo(.{ .ip_address = "invalid" });
    defer res.deinit();

    // Handle the failed case
    if (res.hasError()) {
        std.debug.print("Failed with error code {d}\n", .{res.err.?.status});
        std.debug.print("Error title: {s}\n", .{res.err.?.@"error".title});
        std.debug.print("Error message: {s}\n", .{res.err.?.@"error".message});
    }
}
