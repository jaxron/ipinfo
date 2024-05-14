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
    /// Request failed with an error
    /// different from 200
    Failed: request.Error,
};

/// Contains response information about the batch request
pub const IPInfoBatch = struct {
    /// Contains response body
    body: std.ArrayList(u8),
    /// Contains parsed values from the response body
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

/// Contains response information about the basic query request
pub const IPInfo = struct {
    /// Contains response body
    body: std.ArrayList(u8),
    /// Contains parsed values from the response body
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

/// Contains response information about the filtered query request
pub const FilteredIPInfo = struct {
    /// Filter that was applied
    filter: request.Filter,
    /// Plain response body
    value: ?std.ArrayList(u8) = null,
    /// Information about the error if the request failed
    err: Error,

    /// Releases all allocated memory
    pub fn deinit(self: *const FilteredIPInfo) void {
        self.value.?.deinit();
    }
};

/// Contains all potential information about
/// a given IP as provided by the API
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

/// Required fields to make the basic query request
pub const IPInfoOptions = struct {
    base_url: []const u8 = default_base_url,
    user_agent: []const u8 = default_user_agent,

    /// Used to authenticate the request
    /// and is not required
    api_token: []const u8 = "",

    /// The IP address to query information about
    /// and defaults to your own IP address
    ip_address: []const u8 = "",
};

/// Required fields to make the batch query request
pub const IPInfoBatchOptions = struct {
    base_url: []const u8 = default_base_url,
    user_agent: []const u8 = default_user_agent,

    /// Used to authenticate the request
    /// and must be provided
    api_token: []const u8,

    /// The IP URLs to get information about
    /// in this format: 8.8.8.8/country
    ip_urls: []const []const u8,

    /// Whether or not to hide invalid/empty results
    hide_invalid: bool = false,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    request: request.Request,

    /// Prepares the client to make requests
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

    /// Makes a batch API request and returns the information
    /// for the specified IP URLs
    pub fn getBatchIPInfo(self: *Client, options: IPInfoBatchOptions) !IPInfoBatch {
        // Build the final URL for the batch request
        var final_url = builder.String.init(self.allocator);
        defer final_url.deinit();

        try final_url.concatAll(&.{ options.base_url, "batch" });
        try final_url.concatIf(options.hide_invalid, "?filter=1");

        // Build the payload to be sent in the batch request
        const payload = try std.json.stringifyAlloc(self.allocator, options.ip_urls, .{});
        defer self.allocator.free(payload);

        // Make the request with the given options and payload
        const done = try self.request.post(.{
            .url = final_url.string(),
            .user_agent = options.user_agent,
            .api_token = options.api_token,
            .payload = payload,
        });
        const body = done.body;
        const err = done.err;

        // Check if response is unsuccessful and parse the error message
        if (err.status != .ok) {
            return .{
                .body = body,
                .err = .{ .Failed = err },
            };
        }

        const parsed = try std.json.parseFromSlice(std.json.ArrayHashMap([]const u8), self.allocator, body.items, .{});
        return .{
            .parsed = parsed,
            .body = body,
            .err = .Success,
        };
    }

    /// Makes a basic API request and returns the information
    /// for the specified IP address
    pub fn getIPInfo(self: *Client, options: IPInfoOptions) !IPInfo {
        // Build the final URL for the basic request
        var final_url = builder.String.init(self.allocator);
        defer final_url.deinit();

        try final_url.concatAll(&.{ options.base_url, options.ip_address });

        // Make the request with the given options
        const done = try self.request.get(.{
            .url = final_url.string(),
            .user_agent = options.user_agent,
            .api_token = options.api_token,
        });
        const body = done.body;
        const err = done.err;

        // Check if response is unsuccessful and parse the error message
        if (err.status != .ok) {
            return .{
                .body = body,
                .err = .{ .Failed = err },
            };
        }

        const parsed = try std.json.parseFromSlice(ResultInfo, self.allocator, body.items, .{
            .ignore_unknown_fields = true,
        });
        return .{
            .parsed = parsed,
            .body = body,
            .err = .Success,
        };
    }

    /// Similar to getIPInfo() but makes a basic API request and returns the information
    /// for the specified IP address with a filter for the response
    pub fn getFilteredIPInfo(self: *Client, options: IPInfoOptions, filter: request.Filter) !FilteredIPInfo {
        // Build the final URL for the filtered request
        var final_url = builder.String.init(self.allocator);
        defer final_url.deinit();

        try final_url.concatAll(&.{ options.base_url, options.ip_address });
        try final_url.concatIf(filter != .none and options.ip_address.len != 0, "/");
        try final_url.concatIf(filter != .none, @tagName(filter));

        // Make the request with the given options
        const done = try self.request.get(.{
            .url = final_url.string(),
            .user_agent = options.user_agent,
            .api_token = options.api_token,
        });
        var body = done.body;
        const err = done.err;

        // Removes the trailing newline character that
        // comes with the response body sometimes
        if (body.items[body.items.len - 1] == '\n') {
            _ = body.popOrNull().?;
        }

        // Check if response is unsuccessful and parse the error message
        if (err.status != .ok) {
            return .{
                .filter = filter,
                .value = body,
                .err = .{ .Failed = err },
            };
        }

        return .{
            .filter = filter,
            .value = body,
            .err = .Success,
        };
    }
};
