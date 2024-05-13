const std = @import("std");
const ipinfo = @import("ipinfo");

pub fn main() !void {
    // Initialize the allocator of your choice :)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Before you can use the API client, you need to initialize the client
    // and modify any options if you want to
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Get the secret token to be used for the API
    // For this example, I will be using the argument passed to the program.
    // ./04_batch_fetch.exe -- <token>
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const token = argv[1];

    // Getting the country information for 2 of google's IP addresses
    const res = try c.getBatchIPInfo(.{
        .apiToken = token,
        .ipURLs = &.{
            "8.8.8.8/country",
            "8.8.4.4/country",
        },
        .hideInvalid = true,
    });
    defer res.deinit();

    // Let's see if it works as intended! (which it should...)
    const hashMap = res.parsed.?.value.map;
    for (hashMap.keys(), hashMap.values()) |key, value| {
        std.debug.print("Country for {s} is: {s}\n", .{ key, value });
    }
}
