const std = @import("std");
const builder = @import("string_builder.zig");
const cache = @import("cache");

const default_base_url = "https://ipinfo.io/";
const default_user_agent = "zig-ipinfo-unofficial/0.1.0";

pub fn main() !void {}

/// The cache is used to store successful
/// responses for a certain amount of time
/// which can reduce the number of requests
/// and speed up the application
pub const CacheConfig = struct {
    enabled: bool = true,
    storage: cache.Cache([]u8) = undefined,
    max_items: u32 = 2000,
    ttl: u32 = 3600,
};

/// Contains information needed to make a request
pub const RequestOptions = struct {
    /// There should not be any need to change it
    baseURL: []const u8 = default_base_url,

    /// A unique identifier used in requests
    /// when using this library
    userAgent: []const u8 = default_user_agent,

    /// The token used to authenticate the request
    /// and is left empty by default unless you
    /// have a paid plan
    apiToken: []const u8 = "",

    /// The IP address to get information about
    /// and defaults to your own IP address
    ipAddress: []const u8 = "",
};

/// Contains information needed to filter the data from the response
pub const RequestFilter = union(enum) {
    none,
    ip,
    hostname,
    anycast,
    city,
    region,
    country,
    loc,
    org,
    postal,
    timezone,
    asn,
    company,
    privacy,
    abuse,
    domains,
};

/// Contains information about the request error
pub const RequestError = struct {
    status: std.http.Status = .ok,
    title: []const u8 = "",
    message: []const u8 = "",
};

/// Contains information about the request error
/// if the request failed
pub const Error = union(enum) {
    /// Request was successful with code 200
    Success,
    /// Request failed with a specific error
    /// different from 200
    Failed: RequestError,
};

/// Contains parsed values from the response body
/// without any filter
pub const IPInfo = struct {
    /// The response body
    body: std.ArrayList(u8),
    /// The parsed values from the response body
    parsed: std.json.Parsed(ResultInfo),
    /// Information about the error if the request failed
    err: Error,

    /// Releases all allocated memory
    pub fn deinit(self: *const IPInfo) void {
        if (self.err == .Success) {
            self.parsed.deinit();
        }
        self.body.deinit();
    }
};

/// Contains filtered values from the response body
pub const FilteredIPInfo = struct {
    /// The type of filter used
    filter: RequestFilter,
    /// The plain response body
    value: std.ArrayList(u8),
    /// Information about the error if the request failed
    err: Error,

    /// Releases all allocated memory
    pub fn deinit(self: *const FilteredIPInfo) void {
        self.value.deinit();
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

pub const Client = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    cache: CacheConfig,

    pub const DoResult = struct { body: std.ArrayList(u8), err: RequestError };

    /// Opens a new client in a thread-safe way
    pub fn init(allocator: std.mem.Allocator, config: CacheConfig) !Client {
        return .{
            .allocator = allocator,
            .client = std.http.Client{
                .allocator = allocator,
            },
            .cache = .{
                .storage = try cache.Cache([]u8).init(allocator, .{
                    .max_size = config.max_items,
                }),
            },
        };
    }

    /// Releases all associated resources with the client
    pub fn deinit(self: *Client) void {
        self.client.deinit();
        self.cache.storage.deinit();
    }

    /// Returns IP information for the specified IP address
    pub fn getIPInfo(self: *Client, options: RequestOptions) !IPInfo {
        const done = try self.do(options, .none);
        const body = done.body;
        const err = done.err;

        // Check if response is unsuccessful
        if (err.status != .ok) {
            return .{
                .parsed = undefined,
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
    pub fn getFilteredIPInfo(self: *Client, options: RequestOptions, filter: RequestFilter) !FilteredIPInfo {
        const done = try self.do(options, filter);
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

    /// Makes a request to the IPInfo API
    fn do(self: *Client, options: RequestOptions, filter: RequestFilter) !DoResult {
        // Build the final URL
        var finalURL = builder.String.init(self.allocator);
        defer finalURL.deinit();

        try finalURL.concat(options.baseURL);
        try finalURL.concat(options.ipAddress);
        if (filter != .none) {
            if (options.ipAddress.len != 0) {
                try finalURL.concat("/");
            }
            try finalURL.concat(@tagName(filter));
        }

        // Build the API token
        var apiToken = builder.String.init(self.allocator);
        defer apiToken.deinit();

        try apiToken.concat("Bearer ");
        try apiToken.concat(options.apiToken);

        // Get response from cache if available
        if (self.cache.enabled) {
            if (self.cache.storage.get(finalURL.string())) |entry| {
                defer entry.release();

                // Convert the cache entry to a response body
                var body = std.ArrayList(u8).init(self.allocator);
                try body.appendSlice(entry.value);

                return .{
                    .body = body,
                    .err = .{},
                };
            }
        }

        // Make a request if cache is disabled or not available
        var body = std.ArrayList(u8).init(self.allocator);
        const res = try self.client.fetch(.{
            .method = .GET,
            .location = .{
                .url = finalURL.string(),
            },
            .headers = .{
                .user_agent = .{ .override = options.userAgent },
                .authorization = .{ .override = apiToken.string() },
            },
            .extra_headers = &.{
                .{ .name = "Accept", .value = "application/json" },
            },
            .response_storage = .{
                .dynamic = &body,
            },
        });

        // Check if response is unsuccessful
        if (res.status != .ok) {
            const parsed = try std.json.parseFromSlice(struct {
                status: u10,
                @"error": struct {
                    title: []const u8,
                    message: []const u8,
                },
            }, self.allocator, body.items, .{});
            defer parsed.deinit();

            return .{
                .body = body,
                .err = .{
                    .status = @enumFromInt(parsed.value.status),
                    .title = parsed.value.@"error".title,
                    .message = parsed.value.@"error".message,
                },
            };
        }

        // Cache the response body
        if (self.cache.enabled)
            try self.cache.storage.put(finalURL.string(), body.items, .{ .ttl = self.cache.ttl });

        return .{ .body = body, .err = .{} };
    }
};
