const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // The explanation for all these basic components can be found in
    // the `01_basic_fetch.zig` file. Do take a look at it if you haven't!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Getting the country information for 2 of google's IP addresses
    const res = try client.extra.getIPSummary(.{
        .ips = &.{
            "64.233.160.0", "64.233.160.1", "64.233.160.2", "64.233.160.3", "64.233.160.4", "64.233.160.5", "64.233.160.6", "64.233.160.7", "64.233.160.8", "64.233.160.9",
        },
    });
    defer res.deinit();

    // This contains all the available data for the IP addresses.
    const data = res.parsed.?.value;

    // For instance, we might want to check whether the IPs are
    // from hosting, relay, tor or proxy.
    const hashMap = data.privacy.?.map;

    // Let's print out the info we want to see.
    var iterator = hashMap.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("Data for {s} is: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // // If you want to use the keys and values directly, you can do so like this:
    // for (hashMap.keys(), hashMap.values()) |key, value| {
    //     std.debug.print("Data for {s} is: {s}\n", .{ key, value });
    // }
}
