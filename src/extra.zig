const std = @import("std");
const builder = @import("string_builder.zig");
const request = @import("request.zig");
const ipinfo = @import("ipinfo.zig");

/// Contains response information about the ip summary request
pub const IPSummary = struct {
    /// Contains response body
    body: std.ArrayList(u8),
    /// Contains parsed values from the response body
    parsed: ?std.json.Parsed(SummaryInfo) = null,
    /// Information about the error if the request failed
    err: ?SummaryResultError = null,

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

/// Expected error format from the IP summary response
pub const SummaryResultError = struct {
    @"error": []const u8,
};

/// Contains all potential information about
/// a given IP as provided by the API
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

/// Required fields to make the summary request
pub const IPSummaryOptions = struct {
    base_url: []const u8 = ipinfo.default_base_url,
    user_agent: []const u8 = ipinfo.default_user_agent,

    /// Used to authenticate the request
    /// and is not required
    api_token: []const u8 = "",

    ips: []const []const u8,
};

/// Contains response information about the ip map request
pub const IPMap = struct {
    /// Contains response body
    body: std.ArrayList(u8),
    /// Contains parsed values from the response body
    parsed: ?std.json.Parsed(IPMapInfo) = null,
    /// Information about the error if the request failed
    err: ?MapResultError = null,

    /// Releases all allocated memory
    pub fn deinit(self: *const IPMap) void {
        if (!self.hasError()) {
            self.parsed.?.deinit();
        }
        self.body.deinit();
    }

    /// Returns true if the request had an error
    pub fn hasError(self: *const IPMap) bool {
        return self.err != null;
    }
};

/// Expected error format from the IP map response
pub const MapResultError = struct {
    title: []const u8,
    message: []const u8,
};

/// Required fields to make the map request
pub const IPMapOptions = struct {
    base_url: []const u8 = ipinfo.default_base_url,
    user_agent: []const u8 = ipinfo.default_user_agent,

    /// Used to authenticate the request
    /// and is not required
    api_token: []const u8 = "",

    ips: []const []const u8,
};

/// Contains the report URL of the map request
pub const IPMapInfo = struct {
    status: []const u8,
    reportUrl: []const u8,
};

pub const IPMapReport = struct {
    /// Contains response body
    body: std.ArrayList(u8),
    /// Contains parsed values from the response body
    parsed: ?std.json.Parsed(IPMapReportInfo) = null,
    /// Information about the error if the request failed
    err: ?struct {} = null,

    /// Releases all allocated memory
    pub fn deinit(self: *const IPMapReport) void {
        if (!self.hasError()) {
            self.parsed.?.deinit();
        }
        self.body.deinit();
    }

    /// Returns true if the request had an error
    pub fn hasError(self: *const IPMapReport) bool {
        return self.err != null;
    }
};

/// Contains the information from the map report
pub const IPMapReportInfo = struct {
    created: ?[]const u8 = null,
    locationMap: ?[]struct {
        loc: []const u8,
        city: []const u8,
        count: u32,
        region: []const u8,
        country: []const u8,
    } = null,
    id: ?[]const u8 = null,
    numCities: ?u32 = null,
    numCountries: ?u32 = null,
    should_not_render_widgets: ?bool = null,
    countryCount: ?std.json.ArrayHashMap(u32) = null,
    countryCenteroids: ?std.json.ArrayHashMap([]f32) = null,
    countryFullNames: ?std.json.ArrayHashMap([]const u8) = null,
    total: ?u32 = null,
};

/// Required fields to make the map report request
pub const IPMapReportOptions = struct {
    user_agent: []const u8 = ipinfo.default_user_agent,

    /// Used to authenticate the request
    /// and is not required
    api_token: []const u8 = "",

    report_url: []const u8,
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
        // Build the final URL for the summary request
        var final_url = builder.String.init(self.allocator);
        defer final_url.deinit();

        try final_url.concatAll(&.{ options.base_url, "summarize?cli=1" });

        // Build the payload to be sent in the summary request
        const payload = try std.json.stringifyAlloc(self.allocator, options.ips, .{});
        defer self.allocator.free(payload);

        // Make the request with the given options and payload
        const done = try self.request.post(SummaryResultError, .{
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

    /// Makes a IP Map request and returns the information
    /// for the specified IPs
    pub fn getIPMap(self: *Extra, options: IPMapOptions) !IPMap {
        // Build the final URL for the map request
        var final_url = builder.String.init(self.allocator);
        defer final_url.deinit();

        try final_url.concatAll(&.{ options.base_url, "map?cli=1" });

        // Build the payload to be sent in the map request
        const payload = try std.json.stringifyAlloc(self.allocator, options.ips, .{});
        defer self.allocator.free(payload);

        // Make the request with the given options and payload
        const done = try self.request.post(MapResultError, .{
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

        const parsed = try std.json.parseFromSlice(IPMapInfo, self.allocator, body.items, .{
            .ignore_unknown_fields = true,
        });
        return .{
            .parsed = parsed,
            .body = body,
        };
    }

    /// Using the report URL from getIPMap(), make an IP Map request
    /// and return the information from the report
    pub fn getIPMapReport(self: *Extra, options: IPMapReportOptions) !IPMapReport {
        // Change regular report URL with api report URL
        const final_url = try std.mem.replaceOwned(u8, self.allocator, options.report_url, "https://ipinfo.io/tools/map", "https://ipinfo.io/api/tools/map");
        defer self.allocator.free(final_url);

        // Make the request with the given options and payload
        const done = try self.request.get(struct {}, .{
            .url = final_url,
            .user_agent = options.user_agent,
            .api_token = options.api_token,

            // Without this, the API will return an unintended result
            .remove_accept_header = true,
        });
        defer done.deinit();

        const body = done.body;

        // Check if response is unsuccessful and parse the error message
        if (done.hasError()) {
            return .{
                .body = body,
                .err = .{},
            };
        }

        const parsed = try std.json.parseFromSlice(IPMapReportInfo, self.allocator, body.items, .{
            .ignore_unknown_fields = true,
        });
        return .{
            .parsed = parsed,
            .body = body,
        };
    }
};
