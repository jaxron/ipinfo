const std = @import("std");
const cache = @import("cache");
const builder = @import("string_builder.zig");

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

/// Contains information needed to filter the data from the response
pub const Filter = union(enum) {
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
pub const Error = struct {
    status: std.http.Status = .ok,
    title: []const u8 = "",
    message: []const u8 = "",
};

pub const Request = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    cache: CacheConfig,

    pub const GetOptions = struct {
        url: []const u8,
        userAgent: []const u8,
        apiToken: []const u8,
    };

    // Literally waiting for this D:
    // https://github.com/ziglang/zig/issues/2647
    pub const GetResult = struct { body: std.ArrayList(u8), err: Error };

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
    pub fn get(self: *Request, options: GetOptions) !GetResult {
        // Build the API token
        var apiToken = builder.String.init(self.allocator);
        defer apiToken.deinit();

        try apiToken.concat("Bearer ");
        try apiToken.concat(options.apiToken);

        // Get response from cache if available
        if (self.cache.enabled) {
            if (self.cache.storage.?.get(options.url)) |entry| {
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
                .url = options.url
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
            try self.cache.storage.?.put(options.url, body.items, .{ .ttl = self.cache.ttl });

        return .{ .body = body, .err = .{} };
    }
};
