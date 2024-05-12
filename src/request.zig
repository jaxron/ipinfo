const std = @import("std");
const cache = @import("cache");
const builder = @import("string_builder.zig");

const default_base_url = "https://ipinfo.io/";
const default_user_agent = "zig-ipinfo-unofficial/0.1.0";

/// The cache is used to store successful
/// responses for a certain amount of time
/// which can reduce the number of requests
/// and speed up the application
pub const CacheConfig = struct {
    enabled: bool = true,
    storage: ?cache.Cache([]u8) = undefined,
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

pub const Request = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    cache: CacheConfig,

    // Literally waiting for this D:
    // https://github.com/ziglang/zig/issues/2647
    pub const GetResult = struct { body: std.ArrayList(u8), err: RequestError };

    /// Initializes the client with the specified allocator
    pub fn init(allocator: std.mem.Allocator, config: CacheConfig) !Request {
        return .{
            .allocator = allocator,
            .client = std.http.Client{
                .allocator = allocator,
            },
            .cache = .{
                .enabled = config.enabled,
                .storage = if (config.enabled) try cache.Cache([]u8).init(allocator, .{
                    .max_size = config.max_items,
                }) else null,
                .max_items = config.max_items,
                .ttl = config.ttl,
            },
        };
    }

    /// Releases all associated resources with the client
    pub fn deinit(self: *Request) void {
        self.client.deinit();
        if (self.cache.enabled) self.cache.storage.?.deinit();
    }

    /// Makes a GET request to the IPInfo API
    pub fn get(self: *Request, options: RequestOptions, filter: RequestFilter) !GetResult {
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
            if (self.cache.storage.?.get(finalURL.string())) |entry| {
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
            try self.cache.storage.?.put(finalURL.string(), body.items, .{ .ttl = self.cache.ttl });

        return .{ .body = body, .err = .{} };
    }
};
