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

    // Getting the report URL based on a set of IP addresses.
    const map = try client.extra.getIPMap(.{
        .ips = &.{ "8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1", "94.140.14.14", "94.140.15.15", "9.9.9.9", "149.112.112.112", "76.76.2.0", "76.76.10.0" },
    });
    defer map.deinit();

    // After getting the report URL, we can fetch the data.
    // Yes, two requests are made in this file.
    const report = try client.extra.getIPMapReport(.{
        .report_url = map.parsed.?.value.reportUrl,
    });
    defer report.deinit();

    // This contains all the available data based on the IP addresses
    // that we have provided in the `getIPMap` method.
    const data = report.parsed.?.value;

    // For example, we might want to list the countries that
    // the IP addresses are from.
    const hashMap = data.countryCount.?.map;

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
