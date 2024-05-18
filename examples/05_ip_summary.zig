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

    // Getting a summary of the IP addresses.
    const res = try client.extra.getIPSummary(.{
        .ips = &.{ "8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1", "94.140.14.14", "94.140.15.15", "9.9.9.9", "149.112.112.112", "76.76.2.0", "76.76.10.0" },
    });
    defer res.deinit();

    // This contains all the available data for the IP addresses.
    const data = res.parsed.?.value;

    // For example, we might want to check whether the IPs are
    // from hosting, relay, tor or proxy.
    const hashMap = data.privacy.?.map;

    // Let's print out the info we received using an iterator!
    var iterator = hashMap.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("Data for {s} is: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // // If you want to use the keys and values directly, you can do so like this:
    // for (hashMap.keys(), hashMap.values()) |key, value| {
    //     std.debug.print("Data for {s} is: {s}\n", .{ key, value });
    // }
}
