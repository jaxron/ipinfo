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

    // Before we can use batch requests, an API key is required!
    // For this example, I will be using the argument passed to the program.
    // ./04_batch_fetch.exe -- <token>
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const token = argv[1];

    // Getting the country information for 2 of google's IP addresses
    const res = try client.getBatchIPInfo(.{
        .api_token = token,
        .ip_urls = &.{
            "8.8.8.8/country",
            "8.8.8.8/hostname",
            "8.8.4.4/country",
            "8.8.8.9/hostname",
        },
        // This will hide all the invalid responses from the output.
        // In this case, `8.8.8.9/hostname` is an invalid request.
        .hide_invalid = true,
    });
    defer res.deinit();

    // Let's print out all the information we got!
    const hashMap = res.parsed.?.value.map;

    var iterator = hashMap.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("Data for {s} is: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // // If you want to use the keys and values directly, you can do so like this:
    // for (hashMap.keys(), hashMap.values()) |key, value| {
    //     std.debug.print("Data for {s} is: {s}\n", .{ key, value });
    // }
}
