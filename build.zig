const std = @import("std");

const Example = struct {
    name: []const u8,
    source_file: std.Build.LazyPath,
    description: []const u8,
};

const examples = [_]Example{
    .{
        .name = "basic_fetch",
        .source_file = .{ .path = "examples/01_basic_fetch.zig" },
        .description = "Basic usage of the library",
    },
    .{
        .name = "advanced_fetch",
        .source_file = .{ .path = "examples/02_advanced_fetch.zig" },
        .description = "Advanced usage of the library",
    },
    .{
        .name = "error_handling",
        .source_file = .{ .path = "examples/03_error_handling.zig" },
        .description = "Error handling in the library",
    },
};

pub fn build(b: *std.Build) void {
    // Options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Module
    const opts = .{ .target = target, .optimize = optimize };
    const cache_mod = b.dependency("cache", opts).module("cache");
    const ipinfo_mod = b.addModule("ipinfo", .{
        .root_source_file = .{ .path = "src/ipinfo.zig" },
        .imports = &.{
            .{ .name = "cache", .module = cache_mod },
        },
    });

    // Examples
    inline for (examples) |example| {
        const example_exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = example.source_file,
            .optimize = optimize,
            .target = target,
        });
        example_exe.root_module.addImport("ipinfo", ipinfo_mod);

        const install_step = b.addInstallArtifact(example_exe, .{});

        const run_cmd = b.addRunArtifact(example_exe);
        run_cmd.step.dependOn(&install_step.step);

        const run_step = b.step(example.name, example.description);
        run_step.dependOn(&run_cmd.step);
    }

    // Tests
    const lib_test = b.addTest(.{
        .root_source_file = .{ .path = "src/ipinfo.zig" },
        .optimize = optimize,
        .target = target,
        .test_runner = .{ .path = "test_runner.zig" },
    });
    lib_test.root_module.addImport("cache", cache_mod);

    const run_test = b.addRunArtifact(lib_test);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_test.step);

    // Docs
    const exe = b.addExecutable(.{
        .name = "ipinfo-zig",
        .root_source_file = .{ .path = "src/ipinfo.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Create library documentation");
    docs_step.dependOn(&install_docs.step);
}
