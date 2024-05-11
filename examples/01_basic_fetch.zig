const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // Initialize the allocator of your choice :)
    // https://ziglang.org/documentation/master/#Choosing-an-Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Before you can use the API client, you need to initialize the client
    // and modify any options if you want to
    var c = try ipinfo.Client.init(gpa.allocator(), .{});
    defer c.deinit();

    // Calling the getIPInfo function without any changes to options
    // will return the information of your own IP address
    const res = try c.getIPInfo(.{});
    defer res.deinit();

    // You may also pass an IP address to get the information
    // of that IP address
    const res2 = try c.getIPInfo(.{ .ipAddress = "8.8.8.8" });
    defer res2.deinit();

    // Let's see if it works as intended! (which it should...)
    std.debug.print("Your IP address: {s}\n", .{res.parsed.value.ip.?});
    std.debug.print("Your country: {s}\n", .{res.parsed.value.country.?});

    std.debug.print("Google's country: {s}\n", .{res2.parsed.value.country.?});
    std.debug.print("Google's city: {s}\n", .{res2.parsed.value.city.?});
}
