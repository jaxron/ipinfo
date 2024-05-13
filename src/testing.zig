const std = @import("std");
const builder = @import("string_builder.zig");
const ipinfo = @import("ipinfo.zig");

const t = std.testing;

test "string_builder: concatenation" {
    const allocator = t.allocator;

    // Test string concatenation
    {
        var string = builder.String.init(allocator);
        defer string.deinit();

        const expected = "The quick brown fox jumps over the lazy dog";

        try string.concat(expected);
        try t.expectEqualStrings(expected, string.string());
        try t.expect(string.len() == expected.len);
    }
}

test "client: valid IP address using own IP" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Test with a valid IP address
    const res = try c.getIPInfo(.{});
    defer res.deinit();

    try t.expect(res.err == .Success);
}

test "client: valid IP address using 8.8.8.8" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Test with a valid IP address
    const res = try c.getIPInfo(.{
        .ipAddress = "8.8.8.8",
    });
    defer res.deinit();

    try t.expect(res.err == .Success);
    try t.expectEqualStrings("AS15169 Google LLC", res.parsed.?.value.org.?);
}

test "client: valid IP address with filter" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Test with valid IP address and filter
    const res = try c.getFilteredIPInfo(.{
        .ipAddress = "8.8.8.8",
    }, .country);
    defer res.deinit();

    try t.expect(res.err == .Success);
    try t.expectEqualStrings("US", res.value.?.items);
}

test "client: 2 batch IP address requests" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Get secret token
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const token = argv[1];

    // Test with batch IP addresses
    const res = try c.getBatchIPInfo(.{
        .apiToken = token,
        .ipURLs = &.{
            "8.8.8.8/country",
            "8.8.8.9/hostname",
        },
        .hideInvalid = true,
    });
    defer res.deinit();

    try t.expect(res.err == .Success);
    try t.expect(res.parsed.?.value.map.count() == 1);
    try t.expectEqualStrings("US", res.parsed.?.value.map.values()[0]);

    // Test the cache with the same batch IP addresses
    const res2 = try c.getBatchIPInfo(.{
        .apiToken = token,
        .ipURLs = &.{
            "8.8.8.8/country",
            "8.8.8.9/hostname",
        },
        .hideInvalid = true,
    });
    defer res2.deinit();

    try t.expect(res2.err == .Success);
    try t.expect(res2.parsed.?.value.map.count() == 1);
    try t.expectEqualStrings(res.parsed.?.value.map.values()[0], res2.parsed.?.value.map.values()[0]);
}

test "client: invalid IP address" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Test with an invalid IP address
    const res = try c.getIPInfo(.{
        .ipAddress = "invalid",
    });
    defer res.deinit();

    try t.expect(res.err == .Failed);
    switch (res.err) {
        .Failed => |err| {
            try t.expectEqualStrings("Wrong ip", err.title);
            try t.expectEqualStrings("Please provide a valid IP address", err.message);
        },
        else => unreachable,
    }
}

test "client: 2 valid IP address with cache" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Test with a valid IP address
    const res = try c.getIPInfo(.{});
    defer res.deinit();

    try t.expect(res.err == .Success);

    // Test with a valid IP address
    const res2 = try c.getIPInfo(.{});
    defer res2.deinit();

    try t.expect(res2.err == .Success);

    // Compare the results
    try t.expectEqualStrings(res.body.items, res2.body.items);
}

test "client: 2 valid IP address without cache" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{
        .enabled = false,
    });
    defer c.deinit();

    // Test with a valid IP address
    const res = try c.getIPInfo(.{});
    defer res.deinit();

    try t.expect(res.err == .Success);

    // Test with a valid IP address
    const res2 = try c.getIPInfo(.{});
    defer res2.deinit();

    try t.expect(res2.err == .Success);

    // Compare the results
    try t.expectEqualStrings(res.body.items, res2.body.items);
}

test "client: bogon IP address" {
    const allocator = t.allocator;
    var c = try ipinfo.Client.init(allocator, .{});
    defer c.deinit();

    // Test with a bogon IP address
    const res = try c.getIPInfo(.{
        .ipAddress = "0.0.0.0",
    });
    defer res.deinit();

    try t.expect(res.err == .Success);
    try t.expect(res.parsed.?.value.bogon.?);
}
