# ipinfo

An unofficial API wrapper for [ipinfo.io](https://ipinfo.io) written in [Zig](https://ziglang.org/). 

> [!WARNING]
> This library is still WIP. Not recommended for production yet.

## Features

- [X] Basic IP Query
- [X] Response Filtering
- [X] Error Handling
- [X] Bogon IP Support
- [X] Response Caching
- [X] Batch Requests
- [X] Summarize IPs
- [X] IP Mapping
- [ ] CIDR to IP Range
- [ ] Reverse DNS Lookup
- [ ] Pingable IP Finder

## Installation

1. Add IPInfo to `build.zig.zon`:

```diff
.{
    .name = "test-project",
    .version = "1.0.0",
    .dependencies = .{
+       .ipinfo = .{
+           .url = "https://github.com/jaxron/ipinfo/archive/f8cd65da1a2c089d338dfcefc6cede2df9d577f3.tar.gz",
+           .hash = "1220128f4abf9dd3a09cf47f939b0a7779482ef7d4df977d3b9610b94c0728cb4e77",
+       },
    },
}
```

2. Add IPInfo in `build.zig`

```diff
pub fn build(b: *std.Build) void {
    // Options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build
+   const ipinfo_mod = b.dependency("ipinfo", .{
+       .target = target,
+       .optimize = optimize,
+   }).module("ipinfo");

    const exe = b.addExecutable(.{
        .name = "test-project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
+   exe.root_module.addImport("ipinfo", ipinfo_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

If you need a full project example, it can be found [here](https://github.com/jaxron/test-project/tree/ipinfo).

## Examples

All examples can be found in the [examples directory](https://github.com/jaxron/ipinfo/tree/master/examples).