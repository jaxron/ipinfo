const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // Initialize the allocator of your choice :)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Before you can use the API client, you need to initialize the client
    // and modify any options if you want to
    var c = try ipinfo.Client.init(gpa.allocator(), .{});
    defer c.deinit();

    // Passing google's IP address to get the information
    const res = try c.getIPInfo(.{ .ipAddress = "8.8.8.8" });
    defer res.deinit();

    // Again passing google's IP but the result will only contain the city
    const res2 = try c.getFilteredIPInfo(.{ .ipAddress = "8.8.8.8" }, .city);
    defer res2.deinit();

    // Let's see if it works as intended! (which it should...)
    std.debug.print("Google's country: {s}\n", .{res.parsed.value.country.?});
    std.debug.print("Google's city: {s}\n", .{res2.value.items});
}
