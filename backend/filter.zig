const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const ArrayList = std.ArrayList;
const path = fs.path;

/// Returns true if filename starts with '.'
fn isHidden(name: []const u8) bool {
    return name.len > 0 and name[0] == '.';
}

/// Searches for .gitignore starting from `start_path` (file or directory)
/// and moving up the directory tree until root is reached.
/// Returns the absolute path to the nearest .gitignore file, or error.FileNotFound.
/// Caller owns the returned memory and must free it.
pub fn findGitignore(allocator: mem.Allocator, start_path: []const u8) !?[]const u8 {
    if (start_path.len == 0) return error.InvalidPath;

    // Resolve to absolute path to handle relative paths correctly
    const absolute_start = try fs.realpathAlloc(allocator, start_path);
    defer allocator.free(absolute_start);

    // If start_path is a file, start searching from its directory
    const start_dir = path.dirname(absolute_start) orelse absolute_start;

    var current = try allocator.dupe(u8, start_dir);
    defer allocator.free(current);

    while (true) {
        // Construct path to .gitignore in current directory
        const gitignore_path = try path.join(allocator, &[_][]const u8{ current, ".gitignore" });

        // Check if .gitignore exists and is accessible
        if (fs.accessAbsolute(gitignore_path, .{})) {
            // Found it - return the path
            return gitignore_path;
        } else |_| {
            // Doesn't exist, free and continue searching up
            allocator.free(gitignore_path);
        }

        // Get parent directory
        const parent = path.dirname(current);

        // Check if we've reached the root (parent is null or same as current)
        if (parent == null or mem.eql(u8, parent.?, current)) {
            return null;
        }

        // Move to parent directory for next iteration
        const temp = try allocator.dupe(u8, parent.?);
        allocator.free(current);
        current = temp;
    }
}

/// Simple gitignore rule matcher
/// Note: This is a simplified implementation. For full gitignore support:
/// - Handle negation patterns (!pattern)
/// - Support ** for recursive directory matching
/// - Support ? wildcard
/// - Handle trailing slashes (directory-only patterns)
/// - Respect .gitignore files in subdirectories
/// Consider using a dedicated library for production use.
const Gitignore = struct {
    rules: ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Gitignore {
        return .{
            .rules = ArrayList([]const u8).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Gitignore) void {
        for (self.rules.items) |rule| {
            self.allocator.free(rule);
        }
        self.rules.deinit(self.allocator);
    }

    /// Load .gitignore from the given path and append rules
    /// Returns silently if file doesn't exist
    pub fn load(self: *Gitignore, gitignore_path: []const u8) !void {
        const file = fs.cwd().openFile(gitignore_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB limit
        defer self.allocator.free(content);

        var lines = mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = mem.trim(u8, line, " \t\r");

            // Skip empty lines and comments
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Skip negation patterns for simplicity
            if (trimmed[0] == '!') continue;

            const rule = try self.allocator.dupe(u8, trimmed);
            try self.rules.append(self.allocator, rule);
        }
    }

    /// Check if a name matches any gitignore rule
    pub fn isIgnored(self: Gitignore, name: []const u8) bool {
        for (self.rules.items) |rule| {
            if (matchRule(rule, name)) return true;
        }
        return false;
    }
};

/// Simple glob matcher supporting '*' wildcard
/// This implements a basic wildcard matching algorithm
fn matchRule(rule: []const u8, name: []const u8) bool {
    var rule_idx: usize = 0;
    var name_idx: usize = 0;
    var star_idx: ?usize = null;
    var match_idx: usize = 0;

    while (name_idx < name.len) {
        if (rule_idx < rule.len and rule[rule_idx] == '*') {
            star_idx = rule_idx;
            match_idx = name_idx;
            rule_idx += 1;
        } else if (rule_idx < rule.len and rule[rule_idx] == name[name_idx]) {
            rule_idx += 1;
            name_idx += 1;
        } else if (star_idx != null) {
            rule_idx = star_idx.? + 1;
            match_idx += 1;
            name_idx = match_idx;
        } else {
            return false;
        }
    }

    while (rule_idx < rule.len and rule[rule_idx] == '*') {
        rule_idx += 1;
    }

    return rule_idx == rule.len;
}

/// Recursively finds all valid files in a directory tree
/// A file is valid if:
/// - Its name doesn't start with '.'
/// - It's not matched by any gitignore rule
/// - All its parent directories also satisfy the above
///
/// Returns a list of full paths to valid files.
/// Caller owns the memory and must free each path and the array list.
pub fn findValidFiles(
    allocator: std.mem.Allocator,
    root_path: []const u8,
) !ArrayList([]const u8) {
    var result = ArrayList([]const u8).empty;
    errdefer {
        for (result.items) |item| allocator.free(item);
        result.deinit(allocator);
    }

    var gitignore = Gitignore.init(allocator);
    defer gitignore.deinit();

    try collectValidFiles(allocator, root_path, &gitignore, &result);
    return result;
}

fn collectValidFiles(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    gitignore: *Gitignore,
    result: *ArrayList([]const u8),
) !void {
    // Load .gitignore from current directory
    const gitignore_path = findGitignore(allocator, dir_path) catch |err| {
        switch (err) {
            error.FileNotFound => std.debug.print("No .gitignore found in any parent directory\n", .{}),
            error.InvalidPath => std.debug.print("Invalid path provided\n", .{}),
            else => std.debug.print("Error: {}\n", .{err}),
        }
        return err;
    } orelse try allocator.dupe(u8, ".gitignore");
    defer allocator.free(gitignore_path);
    try gitignore.load(gitignore_path);

    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        const name = entry.name;

        // Skip hidden files/directories
        if (isHidden(name)) continue;

        // Skip gitignored files/directories
        if (gitignore.isIgnored(name)) continue;

        const full_path = try fs.path.join(allocator, &[_][]const u8{ dir_path, name });
        defer allocator.free(full_path);

        switch (entry.kind) {
            .file => {
                const path_copy = try allocator.dupe(u8, full_path);
                try result.append(allocator, path_copy);
            },
            .directory => {
                // Recurse into subdirectories
                try collectValidFiles(allocator, full_path, gitignore, result);
            },
            else => {}, // Skip symlinks and other special files
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <directory>\n", .{args[0]});
        return error.InvalidArgs;
    }

    var valid_files = try findValidFiles(allocator, args[1]);
    defer {
        for (valid_files.items) |file| allocator.free(file);
        valid_files.deinit(allocator);
    }

    std.debug.print("Found {d} valid files in '{s}':\n", .{ valid_files.items.len, args[1] });
    for (valid_files.items) |file| {
        std.debug.print("  {s}\n", .{file});
    }
}
