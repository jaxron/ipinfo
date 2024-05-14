const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // Initialize the allocator of your choice :)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Before you can use the API client, you need to initialize the client
    // and modify any options if you want to
    var client = try ipinfo.Client.init(gpa.allocator(), .{});
    defer client.deinit();

    // Passing an invalid IP address just for this example
    // ! Please do not copy and paste this
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
