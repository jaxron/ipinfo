const std = @import("std");
const cache = @import("cache");
const builder = @import("string_builder.zig");

/// The cache is used to store successful
/// responses for a certain amount of time
/// which can reduce the number of requests
/// and speed up the application
pub const CacheConfig = struct {
    enabled: bool = true,
    storage: ?cache.Cache([]u8) = null,
    max_items: u32 = 2000,
    ttl: u32 = 3600,
};

/// Used for filtering the response
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

/// A helper struct that allows for
/// easier retrieval of the response body
pub const Request = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    cache: CacheConfig,

    /// Required fields to make a GET request
    pub const GetOptions = struct {
        url: []const u8,
        user_agent: []const u8,
        api_token: []const u8,

        /// The accept header may cause a request
        /// to return unintended results. One case
        /// would be in `extra.getIPMapReport`.
        remove_accept_header: bool = false,
    };

    /// Required fields to make a POST request
    pub const PostOptions = struct {
        url: []const u8,
        user_agent: []const u8,
        api_token: []const u8,
        payload: []const u8,
    };

    /// Expected output of the helper
    /// functions called in this struct
    pub fn Result(comptime T: type) type {
        return struct {
            body: std.ArrayList(u8),
            err: ?std.json.Parsed(T) = null,

            /// Releases all associated resources with the result
            pub fn deinit(self: *const Result(T)) void {
                if (self.err != null) self.err.?.deinit();
            }

            /// Returns true if the request had an error
            pub fn hasError(self: *const Result(T)) bool {
                return self.err != null;
            }
        };
    }

    /// Prepares the client to make requests
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

    /// Returns the result of a POST request made based
    /// on the given options
    pub fn post(self: *Request, comptime error_type: type, options: PostOptions) !Result(error_type) {
        // Build the API token for the request
        var api_token = builder.String.init(self.allocator);
        defer api_token.deinit();

        try api_token.concatAll(&.{ "Bearer ", options.api_token });

        // Build cache key to retrieve/store the response
        // * A hash is generated to reduce the key size
        var cache_key = builder.String.init(self.allocator);
        defer cache_key.deinit();

        try cache_key.concatAll(&.{ options.url, ":", options.payload });

        var key_hasher = std.hash.XxHash3.init(0);
        key_hasher.update(cache_key.string());

        const final_hash = try std.fmt.allocPrint(self.allocator, "{d}", .{key_hasher.final()});
        defer self.allocator.free(final_hash);

        // Get response from cache if available
        const cache_res = self.getCacheResult(error_type, final_hash);
        if (cache_res != error.NotFound) return cache_res;

        // Make a request if cache is disabled or not found
        var body = std.ArrayList(u8).init(self.allocator);
        const res = try self.client.fetch(.{
            .method = .POST,
            .location = .{ .url = options.url },
            .headers = .{
                .user_agent = .{ .override = options.user_agent },
                .authorization = .{ .override = api_token.string() },
            },
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Accept", .value = "application/json" },
            },
            .response_storage = .{
                .dynamic = &body,
            },
            .payload = options.payload,
        });

        // Check if response is unsuccessful and parse the error message
        if (res.status != .ok) {
            const parsed = try std.json.parseFromSlice(error_type, self.allocator, body.items, .{});
            return .{ .body = body, .err = parsed };
        }

        // Cache the response body
        if (self.cache.enabled) {
            try self.cache.storage.?.put(final_hash, body.items, .{ .ttl = self.cache.ttl });
        }

        return .{ .body = body };
    }

    /// Returns the result of a GET request made based
    /// on the given options
    pub fn get(self: *Request, comptime error_type: type, options: GetOptions) !Result(error_type) {
        // Build the API token for the request
        var api_token = builder.String.init(self.allocator);
        defer api_token.deinit();

        try api_token.concatAll(&.{ "Bearer ", options.api_token });

        // Get response from cache if available
        const cache_res = self.getCacheResult(error_type, options.url);
        if (cache_res != error.NotFound) return cache_res;

        // Prepare the extra headers for the request
        var extra_headers = std.ArrayList(std.http.Header).init(self.allocator);
        defer extra_headers.deinit();

        if (!options.remove_accept_header) {
            try extra_headers.append(.{ .name = "Accept", .value = "application/json" });
        }

        // Make a request if cache is disabled or not found
        var body = std.ArrayList(u8).init(self.allocator);
        const res = try self.client.fetch(.{
            .method = .GET,
            .location = .{ .url = options.url },
            .headers = .{
                .user_agent = .{ .override = options.user_agent },
                .authorization = .{ .override = api_token.string() },
            },
            .extra_headers = extra_headers.items,
            .response_storage = .{
                .dynamic = &body,
            },
        });

        // Check if response is unsuccessful and parse the error message
        if (res.status != .ok) {
            const parsed = try std.json.parseFromSlice(error_type, self.allocator, body.items, .{});
            return .{ .body = body, .err = parsed };
        }

        // Cache the response body
        if (self.cache.enabled) {
            try self.cache.storage.?.put(options.url, body.items, .{ .ttl = self.cache.ttl });
        }

        return .{ .body = body };
    }

    /// Returns a cached response body if available.
    /// Otherwise, returns error.NotFound
    fn getCacheResult(self: *Request, error_type: type, key: []const u8) !Result(error_type) {
        if (self.cache.enabled) {
            if (self.cache.storage.?.get(key)) |entry| {
                defer entry.release();

                // Convert the cache entry to a response body
                var body = std.ArrayList(u8).init(self.allocator);
                try body.appendSlice(entry.value);

                return .{ .body = body };
            }
        }
        return error.NotFound;
    }
};
