const std = @import("std");
const builder = @import("string_builder.zig");
const request = @import("request.zig");

const default_base_url = "https://ipinfo.io/";
const default_user_agent = "zig-ipinfo-unofficial/0.1.0";

pub fn main() !void {}

/// Contains information about the request error
/// if the request failed
pub const Error = union(enum) {
    /// Request was successful with code 200
    Success,
    /// Request failed with a specific error
    /// different from 200
    Failed: request.Error,
};

/// Contains information about the batch request
pub const IPInfoBatch = struct {
    /// The response body
    body: std.ArrayList(u8),
    /// The parsed values from the response body
    parsed: ?std.json.Parsed(std.json.ArrayHashMap([]const u8)) = null,
    /// Information about the error if the request failed
    err: Error,

    /// Releases all allocated memory
    pub fn deinit(self: *const IPInfoBatch) void {
        if (self.err == .Success) {
            self.parsed.?.deinit();
        }
        self.body.deinit();
    }
};

/// Contains information about the basic request
pub const IPInfo = struct {
    /// The response body
    body: std.ArrayList(u8),
    /// The parsed values from the response body
    parsed: ?std.json.Parsed(ResultInfo) = null,
    /// Information about the error if the request failed
    err: Error,

    /// Releases all allocated memory
    pub fn deinit(self: *const IPInfo) void {
        if (self.err == .Success) {
            self.parsed.?.deinit();
        }
        self.body.deinit();
    }
};

/// Contains filtered values from the response body
pub const FilteredIPInfo = struct {
    /// The type of filter used
    filter: request.Filter,
    /// The plain response body
    value: ?std.ArrayList(u8) = null,
    /// Information about the error if the request failed
    err: Error,

    /// Releases all allocated memory
    pub fn deinit(self: *const FilteredIPInfo) void {
        self.value.?.deinit();
    }
};

/// Contains information about a given IP
/// which is parsed from the response body
pub const ResultInfo = struct {
    ip: ?[]const u8 = null,
    hostname: ?[]const u8 = null,
    bogon: ?bool = null,
    anycast: ?bool = null,
    city: ?[]const u8 = null,
    region: ?[]const u8 = null,
    country: ?[]const u8 = null,
    loc: ?[]const u8 = null,
    org: ?[]const u8 = null,
    postal: ?[]const u8 = null,
    timezone: ?[]const u8 = null,
    asn: ?struct {
        asn: []const u8,
        name: []const u8,
        domain: []const u8,
        route: []const u8,
        type: []const u8,
    } = null,
    company: ?struct {
        name: []const u8,
        domain: []const u8,
        type: []const u8,
    } = null,
    privacy: ?struct {
        vpn: bool,
        proxy: bool,
        tor: bool,
        relay: bool,
        hosting: bool,
        service: []const u8,
    } = null,
    abuse: ?struct {
        address: []const u8,
        country: []const u8,
        email: []const u8,
        name: []const u8,
        network: []const u8,
        phone: []const u8,
    } = null,
    domains: ?struct {
        ip: []const u8,
        total: u32,
        domains: []const []const u8,
    } = null,

    /// Usually not present in the response
    /// and only appears at some situations
    /// e.g. when api token is not provided
    readme: ?[]const u8 = null,
};

/// Contains information needed to make a request
pub const IPInfoOptions = struct {
    baseURL: []const u8 = default_base_url,
    userAgent: []const u8 = default_user_agent,

    /// The token used to authenticate the request
    /// and is left empty by default
    apiToken: []const u8 = "",

    /// The IP address to get information about
    /// and defaults to your own IP address
    ipAddress: []const u8 = "",
};

pub const IPInfoBatchOptions = struct {
    baseURL: []const u8 = default_base_url,
    userAgent: []const u8 = default_user_agent,

    /// The token used to authenticate the request
    /// and must be provided
    apiToken: []const u8,

    /// The IP URLs to get information about
    /// in this format: 8.8.8.8/country
    ipURLs: []const []const u8,

    /// Whether or not to hide invalid/empty results
    hideInvalid: bool = false,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    request: request.Request,

    /// Initializes the client with the specified allocator
    pub fn init(allocator: std.mem.Allocator, config: request.CacheConfig) !Client {
        return .{
            .allocator = allocator,
            .request = try request.Request.init(allocator, config),
        };
    }

    /// Releases all associated resources with the client
    pub fn deinit(self: *Client) void {
        self.request.deinit();
    }

    /// Returns information for the specified IP URLs
    pub fn getBatchIPInfo(self: *Client, options: IPInfoBatchOptions) !IPInfoBatch {
        // Build the final URL
        var finalURL = builder.String.init(self.allocator);
        defer finalURL.deinit();

        try finalURL.concatAll(&.{ options.baseURL, "batch" });
        try finalURL.concatIf(options.hideInvalid, "?filter=1");

        // Build the payload
        const payload = try std.json.stringifyAlloc(self.allocator, options.ipURLs, .{});
        defer self.allocator.free(payload);

        // Make the request
        const done = try self.request.post(.{
            .url = finalURL.string(),
            .userAgent = options.userAgent,
            .apiToken = options.apiToken,
            .payload = payload,
        });
        const body = done.body;
        const err = done.err;

        // Check if response is unsuccessful
        if (err.status != .ok) {
            return .{
                .body = body,
                .err = .{ .Failed = err },
            };
        }

        // Parse if the request was successful
        const parsed = try std.json.parseFromSlice(std.json.ArrayHashMap([]const u8), self.allocator, body.items, .{});
        return .{
            .parsed = parsed,
            .body = body,
            .err = .Success,
        };
    }

    /// Returns IP information for the specified IP address
    pub fn getIPInfo(self: *Client, options: IPInfoOptions) !IPInfo {
        // Build the final URL
        var finalURL = builder.String.init(self.allocator);
        defer finalURL.deinit();

        try finalURL.concatAll(&.{ options.baseURL, options.ipAddress });

        // Make the request
        const done = try self.request.get(.{
            .url = finalURL.string(),
            .userAgent = options.userAgent,
            .apiToken = options.apiToken,
        });
        const body = done.body;
        const err = done.err;

        // Check if response is unsuccessful
        if (err.status != .ok) {
            return .{
                .body = body,
                .err = .{ .Failed = err },
            };
        }

        // Parse if the request was successful
        const parsed = try std.json.parseFromSlice(ResultInfo, self.allocator, body.items, .{
            .ignore_unknown_fields = true,
        });

        return .{
            .parsed = parsed,
            .body = body,
            .err = .Success,
        };
    }

    /// Returns IP information for the specified IP address with a filter for the response
    pub fn getFilteredIPInfo(self: *Client, options: IPInfoOptions, filter: request.Filter) !FilteredIPInfo {
        // Build the final URL
        var finalURL = builder.String.init(self.allocator);
        defer finalURL.deinit();

        try finalURL.concatAll(&.{ options.baseURL, options.ipAddress });
        try finalURL.concatIf(filter != .none and options.ipAddress.len != 0, "/");
        try finalURL.concatIf(filter != .none, @tagName(filter));

        // Make the request
        const done = try self.request.get(.{
            .url = finalURL.string(),
            .userAgent = options.userAgent,
            .apiToken = options.apiToken,
        });
        var body = done.body;
        const err = done.err;

        // * Removes the trailing newline character (man i hate this)
        if (body.items[body.items.len - 1] == '\n')
            _ = body.popOrNull().?;

        // Check if response is unsuccessful
        if (err.status != .ok) {
            return .{
                .filter = filter,
                .value = body,
                .err = .{ .Failed = err },
            };
        }

        // Parse if the request was successful
        return .{
            .filter = filter,
            .value = body,
            .err = .Success,
        };
    }
};
