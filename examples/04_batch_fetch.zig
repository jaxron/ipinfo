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
    const res = try client.basic.getBatchIPInfo(.{
        .api_token = token,
        .ip_urls = &.{
            "8.8.8.8/country",
            "8.8.8.8/hostname",
            "8.8.4.4/country",
            "8.8.8.9/hostname",
            "this_is_invalid/hostname",
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
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        switch (value) {
            // The expect value from the value is a string.
            .string => |inner| std.debug.print("Data for {s} is: {s}\n", .{ key, inner }),
            // However, if the value is an object, it means that an error occurred.
            // We can parse the error message from the object.
            .object => {
                const parsed = try client.basic.getErrorFromObject(value);
                defer parsed.deinit();

                std.debug.print("Error for {s}\nTitle: {s}\nMessage: {s}\n\n", .{ key, parsed.value.@"error".title, parsed.value.@"error".message });
            },
            else => {},
        }
    }
}
