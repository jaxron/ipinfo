const std = @import("std");
const builder = @import("string_builder.zig");
const request = @import("request.zig");
const basic = @import("basic.zig");
const extra = @import("extra.zig");

pub const default_base_url = "https://ipinfo.io/";
pub const default_user_agent = "zig-ipinfo-unofficial/0.1.0";

pub fn main() !void {}

pub const Client = struct {
    allocator: std.mem.Allocator,
    basic: basic.Basic,
    extra: extra.Extra,

    /// Prepares the client to make requests
    pub fn init(allocator: std.mem.Allocator, config: request.CacheConfig) !Client {
        return .{
            .allocator = allocator,
            .basic = try basic.Basic.init(allocator, config),
            .extra = try extra.Extra.init(allocator, config),
        };
    }

    /// Releases all associated resources with the client
    pub fn deinit(self: *Client) void {
        self.basic.deinit();
        self.extra.deinit();
    }
};
