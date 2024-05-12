const std = @import("std");
const builder = @import("string_builder.zig");
const request = @import("request.zig");

pub fn main() !void {}

/// Contains information about the request error
/// if the request failed
pub const Error = union(enum) {
    /// Request was successful with code 200
    Success,
    /// Request failed with a specific error
    /// different from 200
    Failed: request.RequestError,
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
    filter: request.RequestFilter,
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

    /// Returns IP information for the specified IP address
    pub fn getIPInfo(self: *Client, options: request.RequestOptions) !IPInfo {
        const done = try self.request.get(options, .none);
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
    pub fn getFilteredIPInfo(self: *Client, options: request.RequestOptions, filter: request.RequestFilter) !FilteredIPInfo {
        const done = try self.request.get(options, filter);
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
