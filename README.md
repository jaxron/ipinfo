# ipinfo

An unofficial API wrapper for [ipinfo.io](https://ipinfo.io) written in [Zig](https://ziglang.org/).

## Installation

1. Add IPInfo to `build.zig.zon`:

```diff
.{
    .name = "test-project",
    .version = "1.0.0",
    .dependencies = .{
+       .ipinfo = .{
+           .url = "https://github.com/jaxron/ipinfo/archive/e93e057bda8fae57b53a4edb991b6b4a6555cf44.tar.gz",
+           .hash = "1220754f621befa733b3300463d3c5ab3b00bb2e3aa6c4324e08fb37bd524b200932",
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