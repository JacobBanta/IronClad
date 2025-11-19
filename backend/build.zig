const std = @import("std");

pub fn build(b: *std.Build) void {
    const release_targets = .{
        std.Target.Query{ .os_tag = .windows, .cpu_arch = .x86_64 },
        std.Target.Query{ .os_tag = .macos, .cpu_arch = .x86_64 },
        std.Target.Query{ .os_tag = .macos, .cpu_arch = .aarch64 },
        std.Target.Query{ .os_tag = .linux, .cpu_arch = .x86_64 },
    };
    if (b.option(bool, "release", "build executable for all targets") orelse false) {
        inline for (release_targets) |release_target| {
            const mod = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = b.resolveTargetQuery(release_target), .optimize = .ReleaseSafe });
            const exe = b.addExecutable(.{ .name = "IronClad_" ++ @tagName(release_target.os_tag.?) ++ "_" ++ @tagName(release_target.cpu_arch.?), .root_module = mod });
            b.installArtifact(exe);
        }
    } else {
        const optimize = b.standardOptimizeOption(.{});
        const debug_target = b.standardTargetOptions(.{});
        const mod = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = debug_target, .optimize = optimize });
        const exe = b.addExecutable(.{ .name = "IronClad-debug", .root_module = mod });
        const clap = b.dependency("clap", .{});
        exe.root_module.addImport("clap", clap.module("clap"));
        b.installArtifact(exe);
    }
}
