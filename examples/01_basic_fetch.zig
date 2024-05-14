const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // Initialize the allocator of your choice :)
    // https://ziglang.org/documentation/master/#Choosing-an-Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Before you can use the API client, you need to initialize the client
    // and modify any options if you want to. In this case, we won't be
    // modifying any options.
    var client = try ipinfo.Client.init(gpa.allocator(), .{});
    defer client.deinit();

    // Calling the getIPInfo() function will return the information of
    // the given IP address. In this case, we're not passing any IP address
    // so it will return the information of our own IP address.
    const res = try client.getIPInfo(.{});
    defer res.deinit();

    // Hence, you may also pass an IP address to get the information
    // of that IP address
    const res2 = try client.getIPInfo(.{ .ip_address = "8.8.8.8" });
    defer res2.deinit();

    // Let's print the information of our own IP address and Google's IP address
    std.debug.print("Your IP address: {s}\n", .{res.parsed.?.value.ip.?});
    std.debug.print("Your country: {s}\n", .{res.parsed.?.value.country.?});

    std.debug.print("Google's country: {s}\n", .{res2.parsed.?.value.country.?});
    std.debug.print("Google's city: {s}\n", .{res2.parsed.?.value.city.?});
}
