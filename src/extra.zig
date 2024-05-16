const std = @import("std");
const builder = @import("string_builder.zig");
const request = @import("request.zig");
const ipinfo = @import("ipinfo.zig");

/// Contains response information about the basic query request
pub const IPSummary = struct {
    /// Contains response body
    body: std.ArrayList(u8),
    /// Contains parsed values from the response body
    parsed: ?std.json.Parsed(SummaryInfo) = null,
    /// Information about the error if the request failed
    err: ?ResultError = null,

    /// Releases all allocated memory
    pub fn deinit(self: *const IPSummary) void {
        if (!self.hasError()) {
            self.parsed.?.deinit();
        }
        self.body.deinit();
    }

    /// Returns true if the request had an error
    pub fn hasError(self: *const IPSummary) bool {
        return self.err != null;
    }
};

const SummaryInfo = struct {
    total: ?u32 = null,
    unique: ?u32 = null,
    anycast: ?u32 = null,
    asns: ?std.json.ArrayHashMap(u32) = null,
    bogon: ?u32 = null,
    carriers: ?std.json.ArrayHashMap(u32) = null,
    companies: ?std.json.ArrayHashMap(u32) = null,
    countries: ?std.json.ArrayHashMap(u32) = null,
    cities: ?std.json.ArrayHashMap(u32) = null,
    domains: ?std.json.ArrayHashMap(u32) = null,
    ipTypes: ?std.json.ArrayHashMap(u32) = null,
    mobile: ?u32 = null,
    privacy: ?std.json.ArrayHashMap(u32) = null,
    privacyServices: ?std.json.ArrayHashMap(u32) = null,
    regions: ?std.json.ArrayHashMap(u32) = null,
    routes: ?std.json.ArrayHashMap(u32) = null,
};

const IPSummaryOptions = struct {
    base_url: []const u8 = ipinfo.default_base_url,
    user_agent: []const u8 = ipinfo.default_user_agent,

    /// Used to authenticate the request
    /// and is not required
    api_token: []const u8 = "",

    ips: []const []const u8,
};

/// Expected error format from the response
pub const ResultError = struct {
    @"error": []const u8,
};

/// The extra types of requests that can be made
pub const Extra = struct {
    allocator: std.mem.Allocator,
    request: request.Request,

    /// Prepares the client to make requests
    pub fn init(allocator: std.mem.Allocator, config: request.CacheConfig) !Extra {
        return .{
            .allocator = allocator,
            .request = try request.Request.init(allocator, config),
        };
    }

    /// Releases all associated resources with the client
    pub fn deinit(self: *Extra) void {
        self.request.deinit();
    }

    /// Makes a IP Summary request and returns the information
    /// for the specified IPs
    pub fn getIPSummary(self: *Extra, options: IPSummaryOptions) !IPSummary {
        // Build the final URL for the batch request
        var final_url = builder.String.init(self.allocator);
        defer final_url.deinit();

        try final_url.concatAll(&.{ options.base_url, "summarize?cli=1" });

        // Build the payload to be sent in the batch request
        const payload = try std.json.stringifyAlloc(self.allocator, options.ips, .{});
        defer self.allocator.free(payload);

        // Make the request with the given options and payload
        const done = try self.request.post(ResultError, .{
            .url = final_url.string(),
            .user_agent = options.user_agent,
            .api_token = options.api_token,
            .payload = payload,
        });
        defer done.deinit();

        const body = done.body;

        // Check if response is unsuccessful and parse the error message
        if (done.hasError()) {
            return .{
                .body = body,
                .err = done.err.?.value,
            };
        }

        const parsed = try std.json.parseFromSlice(SummaryInfo, self.allocator, body.items, .{
            .ignore_unknown_fields = true,
        });
        return .{
            .parsed = parsed,
            .body = body,
        };
    }
};
