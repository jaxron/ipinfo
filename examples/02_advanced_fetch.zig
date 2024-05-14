const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // The explanation for all these basic components can be found in
    // the `01_basic_fetch.zig` file. Do take a look at it if you haven't!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var client = try ipinfo.Client.init(gpa.allocator(), .{});
    defer client.deinit();

    // This time, let's try to use google's IP but we will set a filter such that
    // the result will only contain the city.
    const res = try client.getFilteredIPInfo(.{ .ip_address = "8.8.8.8" }, .city);
    defer res.deinit();

    // // Also, if you do want to pass in your own api token, you can do so by:
    // const res = try client.getFilteredIPInfo(.{
    //     .ip_address = "8.8.8.8",
    //     .api_token = "your_api_token_here",
    // }, .city);
    // defer res.deinit();

    // Let's print out the information and see if we got the city!
    std.debug.print("Google's country: {s}\n", .{res.value.?.items});
}
