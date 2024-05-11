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
+           .url = "https://github.com/jaxron/ipinfo/archive/5fe224ff495bc5b78b76771dca22122733f8d531.tar.gz",
+           .hash = "1220da996c65cda6cdfbe0ca65e6ee9323971d94f46618adadd39099087d36f468c4",
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