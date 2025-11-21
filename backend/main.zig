const clap = @import("clap");
const std = @import("std");
const filter = @import("filter.zig");
const mvzr = @import("mvzr");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const help_message =
        \\-h, --help                    Display this help and exit.
        \\-j, --json                    Formats the output in JSON.
        \\-p, --provider <PROVIDER>     Select between multiple providers. Defaults to ollama.
        \\          ollama
        \\          openrouter
        \\          vscode
        \\-e, --endpoint <STRING>       If provider is Ollama, the endpoint may be specified. Defaults to local.
        \\-m, --model <STRING>          Specify a model to use.
        \\-l, --list-models             List out each model provided by the selected provider.
        \\-c, --config <FILE>           Specify the config file.
        \\-o, --output <PATH>           Specify the output path.
        \\    --max-tokens <INTEGER>    The maximum tokens that a rquest is allowed to consume.
        \\-M, --mode <MODE>             Specify operation mode. Defaults to diff.
        \\          full                Do a full code scan.
        \\          diff                Do a scan over the git diffs.
        \\          file                Do a spot check on a file.
        \\    --diff <STRING>           If mode is diff, specify a commit to do a diff against.
        \\    --file <FILE>             If mode is file, specify file for the spot check.
        \\<STRING>                      Optional path.
        \\
    ;

    const params = comptime clap.parseParamsComptime(help_message);
    const parsers = comptime .{
        .STRING = clap.parsers.string,
        .FILE = clap.parsers.string,
        .PATH = clap.parsers.string,
        .INTEGER = clap.parsers.int(isize, 10),
        .PROVIDER = clap.parsers.enumeration(enum { ollama, openrouter, vscode }),
        .MODE = clap.parsers.enumeration(enum { full, diff, file }),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    // creates a buffered writer to stdout
    var stdout_storage: [256]u8 = undefined;
    var stdout_state = std.fs.File.stdout().writer(&stdout_storage);
    const out = &stdout_state.interface;

    if (res.args.help != 0) {
        std.debug.print(help_message, .{});
        return;
    }

    if (res.args.provider orelse .ollama == .ollama) {
        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        const endpoint = res.args.endpoint orelse "http://127.0.0.1:11434";

        if (res.args.@"list-models" != 0) {
            var response_writer = std.Io.Writer.Allocating.init(allocator);
            defer response_writer.deinit();
            var url_buffer: [64]u8 = undefined;
            const url = try std.fmt.bufPrint(&url_buffer, "{s}/api/tags", .{endpoint});

            const fetch_result = client.fetch(.{
                .location = .{ .url = url },
                .response_writer = &response_writer.writer,
            }) catch |e| {
                std.debug.print("{any}\n", .{e});
                std.process.exit(1);
            };
            if (@intFromEnum(fetch_result.status) != 200) {
                std.debug.print("ERROR: non 200 status: {d}\n", .{@intFromEnum(fetch_result.status)});
                std.process.exit(1);
            }

            const object = try std.json.parseFromSlice(struct { models: []const struct { name: []const u8 } }, allocator, response_writer.written(), .{ .allocate = .alloc_if_needed, .ignore_unknown_fields = true });
            defer object.deinit();

            // chooses which format to print
            if (res.args.json != 0) {
                try std.json.Stringify.value(object.value, .{}, out);
                try out.flush();
                return;
            } else {
                for (object.value.models) |model| {
                    try out.print("{s}\n", .{model.name});
                }
                try out.flush();
                return;
            }
        }
        if (res.args.model != null) {
            switch (res.args.mode orelse .file) {
                .file => {
                    var output = try process(res, allocator, &client, res.args.file orelse return error.NoFileGiven);
                    defer output.deinit();
                    const msg = try std.json.parseFromSlice(struct { message: struct { content: []const u8 } }, allocator, output.written(), .{ .ignore_unknown_fields = true });
                    defer msg.deinit();

                    if (res.args.json != 0) {
                        const escaped = try escapeString(allocator, msg.value.message.content);
                        defer allocator.free(escaped);
                        try out.print("[ {{ \"file\": \"{s}\", \"summary\": \"{s}\" }} ]", .{ res.args.file.?, escaped });
                    } else {
                        _ = try out.writeAll(msg.value.message.content);
                    }
                    try out.flush();
                    return;
                },
                .full => {
                    var valid_files = try filter.findValidFiles(allocator, res.positionals[0] orelse ".");
                    defer {
                        for (valid_files.items) |file| allocator.free(file);
                        valid_files.deinit(allocator);
                    }
                    if (res.args.json != 0) {
                        _ = try out.writeAll("[ ");
                    }

                    const SlimmedDownRegex = mvzr.SizedRegex(10000, 1000);

                    var code_regex = SlimmedDownRegex.compile(
                        // thank you claude
                        \\^.+\.(c|h|cpp|cc|cxx|hpp|hxx|h\+\+|py|go|rs|zig|js|ts|jsx|tsx|mjs|mts|java|cs|rb|php|swift|kt|kts|scala|hs|lhs|clj|cljs|cljc|ex|exs|erl|r|pl|pm|lua|sh|bash|ps1|psd1|psm1|groovy|gradle|jl|dart|vue|svelte|vim|asm|s|m|mm|pas|pp|ada|ads|adb|cob|cbl|cobol|f|f90|f95|f03|for|lisp|lsp|cl|scm|ss|sql|pls|fish|tcl|awk|sed|md|markdown|txt|rst|tex|asciidoc|adoc|json|yaml|yml|toml|xml|csv|tsv|proto|graphql|lock)|(go\.mod|go\.sum|build\.zig\.zon|Cargo\.(toml|lock)|package(-lock)?\.json|yarn\.lock|pnpm-lock\.yaml|Gemfile(\.lock)?|requirements\.txt|setup\.(py|cfg)|pyproject\.toml|poetry\.lock|Makefile|GNUmakefile|CMakeLists\.txt|build\.gradle|settings\.gradle|pom\.xml|tsconfig\.json|Dockerfile|docker-compose\.(ya?ml)|\.env(\..+)?|Procfile|Rakefile|Cakefile|Taskfile|Justfile|Fastfile|Guardfile|Vagrantfile|Berksfile|SConstruct|SConscript|Jenkinsfile|\.gitignore|\.gitattributes|\.editorconfig|\.npmrc|\.htaccess|nginx\.conf|\.bashrc|\.bash_profile|\.zshrc|\.profile|\.vimrc|\.tmux\.conf|init\.(vim|lua)|\.eslintrc(\.(json|js|ya?ml))?|\.prettierrc(\.(json|js|ya?ml))?|\.gitlab-ci\.(ya?ml)|\.github\/workflows\/.*\.(ya?ml)|\.circleci/config\.(ya?ml))$
                    ).?;

                    for (valid_files.items, 0..) |file, i| {
                        if (code_regex.isMatch(file)) {
                            var output = try process(res, allocator, &client, file);
                            defer output.deinit();
                            const msg = try std.json.parseFromSlice(struct { message: struct { content: []const u8 } }, allocator, output.written(), .{ .ignore_unknown_fields = true });
                            defer msg.deinit();
                            if (res.args.json != 0) {
                                const escaped = try escapeString(allocator, msg.value.message.content);
                                defer allocator.free(escaped);
                                try out.print("{{ \"file\": \"{s}\", \"summary\": \"{s}\" }}", .{ file, escaped });
                                if (i != valid_files.items.len - 1)
                                    _ = try out.writeAll(", ");
                            } else {
                                _ = try out.writeAll(msg.value.message.content);
                            }
                        }
                    }
                    if (res.args.json != 0) {
                        _ = try out.writeAll(" ]");
                    }
                    try out.flush();
                    return;
                },
                else => {},
            }
        }
    }
    std.debug.print("Unsupported usage.\nUse -h to display help message.\n", .{});
}

pub fn process(res: anytype, allocator: std.mem.Allocator, client: *std.http.Client, filename: []const u8) !std.Io.Writer.Allocating {
    var response_writer = std.Io.Writer.Allocating.init(allocator);
    defer response_writer.deinit();
    var user2 = std.Io.Writer.Allocating.init(allocator);
    defer user2.deinit();
    var final_response_writer = std.Io.Writer.Allocating.init(allocator);
    const endpoint = res.args.endpoint orelse "http://127.0.0.1:11434";
    var url_buffer: [64]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "{s}/api/chat", .{endpoint});

    var payload = std.Io.Writer.Allocating.init(allocator);
    defer payload.deinit();
    const system = try escapeString(allocator, //{{{
        \\You are an expert security analyst specializing in static code analysis. Your task is to analyze provided source code files and identify potential security vulnerabilities.
        \\
        \\ANALYSIS APPROACH:
        \\- Examine ONLY the code explicitly provided to you
        \\- Standard library functions are assumed safe unless you have a specific CVE/GHSA identifier
        \\- "No vulnerabilities detected" is the NORMAL and EXPECTED outcome for most code
        \\- Only report vulnerabilities you can prove with direct code evidence
        \\
        \\SEVERITY CLASSIFICATION:
        \\- CRITICAL: Remote code execution, authentication bypass, or severe memory corruption with a complete exploitation chain visible in the code
        \\- HIGH: Denial of service, privilege escalation, or significant data manipulation
        \\- MEDIUM: Information disclosure or partial data manipulation requiring complex attack
        \\- LOW: Minor issues, best practice violations, minimal impact
        \\
        \\SPECIFIC RULES FOR CRITICAL:
        \\- CRITICAL requires overwhelming evidence and a complete exploitation path
        \\- Integer/float overflow is ONLY CRITICAL if it DIRECTLY causes memory corruption (not just panics or errors)
        \\- When uncertain between CRITICAL and HIGH, always choose HIGH
        \\
        \\OUTPUT FORMAT:
        \\For each vulnerability found, provide:
        \\1. Severity level
        \\2. Vulnerability type
        \\3. Exact location
        \\4. Vulnerable code snippet
        \\5. Description based on code evidence
        \\6. Potential impact
        \\7. Recommended fix
        \\
        \\CRITICAL FLAGGING:
        \\- Include `CRITICAL` at the start only if you found critical vulnerabilities
        \\- If no critical vulnerabilities exist, do NOT use the word `CRITICAL` anywhere
        \\
        \\BREVITY RULE:
        \\- If you find NO vulnerabilities, respond with exactly: "No vulnerabilities detected."
        \\- Do NOT add any additional text, explanations, or advice
        \\- This is the expected and correct response for safe code
        \\
        \\BEFORE REPORTING ANY VULNERABILITY:
        \\- Verify it's not a standard library function (these are safe)
        \\- Verify you have direct code evidence for every claim
        \\- Verify you're not speculating about data flow or runtime behavior
        \\- When in doubt, classify as LOW/MEDIUM, not CRITICAL
        \\
        \\Focus on accuracy over quantity. Most code has no vulnerabilities, and that's normal.
    ); //}}}
    defer allocator.free(system);
    const user = try processFile(filename, allocator);
    defer allocator.free(user);

    try payload.writer.print("{{ \"model\": \"{s}\", \"messages\": [{{ \"role\": \"system\", \"content\": \"{s}\" }}, {{ \"role\": \"user\", \"content\": \"{s}\" }}], \"temperature\": 0.1, \"stream\": false }}", .{ res.args.model.?, system, user });
    try payload.writer.flush();

    for (0..10) |i| {
        try user2.writer.print("\\n\\nrun {d}:\\n", .{i + 1});
        const fetch_result = client.fetch(.{
            .location = .{ .url = url },
            .response_writer = &response_writer.writer,
            .payload = payload.written(),
        }) catch |e| {
            std.debug.print("{any}\n", .{e});
            std.process.exit(1);
        };
        if (@intFromEnum(fetch_result.status) != 200) {
            std.debug.print("error: non 200 status code: {d}: {?s}\n", .{ @intFromEnum(fetch_result.status), fetch_result.status.phrase() });
            std.process.exit(1);
        }
        const msg = try std.json.parseFromSlice(struct { message: struct { content: []const u8 } }, allocator, response_writer.written(), .{ .ignore_unknown_fields = true });
        defer msg.deinit();
        const string = try escapeString(allocator, msg.value.message.content);
        defer allocator.free(string);
        _ = try user2.writer.write(string);
        response_writer.clearRetainingCapacity();
    }
    var payload2 = std.Io.Writer.Allocating.init(allocator);
    defer payload2.deinit();
    const system2 = try escapeString(allocator, //{{{
        \\You are an expert security analyst specializing in aggregating and correlating static code analysis results from multiple scanning runs. Your task is to analyze multiple vulnerability reports and produce a consolidated, accurate summary.
        \\
        \\AGGREGATION PRINCIPLES:
        \\- **Consensus matters**: Vulnerabilities reported consistently across multiple runs are more likely to be real
        \\- **Solo findings are suspicious**: A vulnerability found in only 1 of 10 runs is likely a false positive
        \\- **Standard library functions are safe**: If any report claims a stdlib vulnerability, treat it as a false positive
        \\- **CRITICAL findings require overwhelming evidence**: Only flag CRITICAL if multiple runs independently confirm it
        \\
        \\ANALYSIS PROCESS:
        \\1. Count how many runs reported "No vulnerabilities detected"
        \\2. Extract all vulnerability findings from runs that reported issues
        \\3. Group findings by: vulnerability type, location, and code snippet
        \\4. For each distinct finding, note how many runs reported it
        \\5. Apply false positive heuristics (see below)
        \\6. Consolidate findings and assign confidence levels
        \\
        \\FALSE POSITIVE HEURISTICS:
        \\- **Single-run findings**: Automatically suspect unless extremely well-documented
        \\- **Stdlib claims**: Always false positives (Go/Rust/Zig stdlibs are memory-safe)
        \\- **Inconsistent details**: Same location but different descriptions = likely hallucination
        \\- **Severity escalation**: "Error" → "RCE" without clear mechanism = downgrade
        \\- **Missing evidence**: No code snippet or vague location = discard
        \\
        \\CONFIDENCE LEVELS:
        \\- **HIGH**: 3+ runs report identical vulnerability with same location and code
        \\- **MEDIUM**: 2 runs report similar vulnerability with consistent details
        \\- **LOW**: Single run reports vulnerability (treat as probable false positive)
        \\- **FALSE POSITIVE**: Stdlib claims or contradictory reports
        \\
        \\OUTPUT FORMAT:
        \\```
        \\SUMMARY
        \\Total runs analyzed: [N]
        \\Runs with no findings: [N]
        \\Runs with findings: [N]
        \\
        \\CONSOLIDATED FINDINGS:
        \\[If none]: No vulnerabilities detected across all runs.
        \\
        \\[If findings exist, for each]:
        \\1. Vulnerability: [Type]
        \\   Severity: [LOW/MEDIUM/HIGH/CRITICAL]
        \\   Location: [File:Line]
        \\   Code: [Snippet]
        \\   Confidence: [HIGH/MEDIUM/LOW]
        \\   Reported in: [X of N runs]
        \\   Description: [Consolidated description from reports]
        \\   Recommended fix: [Consolidated fix]
        \\
        \\CRITICAL SUMMARY:
        \\[If any CRITICAL findings with HIGH/MEDIUM confidence, list them]
        \\[If no CRITICAL findings, state: "No CRITICAL vulnerabilities confirmed"]
        \\
        \\FALSE POSITIVES IDENTIFIED:
        \\[List any findings you flagged as false positives with reasoning]
        \\```
        \\
        \\Some of these fields may be ommited if they are not relevant.
        \\
        \\CRITICAL FLAGGING RULES:
        \\- Include `CRITICAL` at the start of your response ONLY if you have HIGH or MEDIUM confidence CRITICAL findings
        \\- If no CRITICAL vulnerabilities are confirmed, do NOT use the word `CRITICAL` anywhere in your response
        \\
        \\EXAMPLE OUTPUT:
        \\```
        \\SUMMARY
        \\Total runs analyzed: 10
        \\Runs with no findings: 9
        \\Runs with findings: 1
        \\
        \\CONSOLIDATED FINDINGS:
        \\No vulnerabilities detected across all runs.
        \\
        \\FALSE POSITIVES IDENTIFIED:
        \\- Claimed buffer overflow in strconv.ParseFloat (1 run) - Go stdlib is memory-safe, this is a false positive
        \\```
        \\
        \\EXAMPLE OUTPUT 2:
        \\```
        \\SUMMARY
        \\Total runs analyzed: 10
        \\Runs with no findings: 10
        \\Runs with findings: 0
        \\
        \\CONSOLIDATED FINDINGS:
        \\No vulnerabilities detected.
        \\```
        \\
        \\Focus on producing a conservative, accurate summary that prioritizes avoiding false positives over reporting questionable findings.
    ); //}}}
    defer allocator.free(system2);

    try payload2.writer.print("{{ \"model\": \"{s}\", \"messages\": [{{ \"role\": \"system\", \"content\": \"{s}\" }}, {{ \"role\": \"user\", \"content\": \"{s}\" }}], \"temperature\": 0.1, \"stream\": false }}", .{ res.args.model.?, system2, user2.written() });
    try payload2.writer.flush();
    const fetch_result = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &final_response_writer.writer,
        .payload = payload2.written(),
    }) catch |e| {
        std.debug.print("{any}\n", .{e});
        std.process.exit(1);
    };
    if (@intFromEnum(fetch_result.status) != 200) {
        std.debug.print("error: non 200 status code: {d}: {?s}\n", .{ @intFromEnum(fetch_result.status), fetch_result.status.phrase() });
        return final_response_writer;
        //std.process.exit(1);
    }
    return final_response_writer;
}

pub fn processFile(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    var readBuffer: [64]u8 = undefined;
    var fileReader = file.reader(&readBuffer);
    var reader = fileReader.interface.adaptToOldInterface();
    const size = try fileReader.getSize();
    const buf = try reader.readAllAlloc(allocator, size);
    defer allocator.free(buf);
    const fileContents = try escapeString(allocator, buf);
    defer allocator.free(fileContents);
    return try std.mem.join(allocator, "", &.{ "filename: `", filename, "`. contents: \\n", fileContents });
}

/// Escapes special characters: \\, \", \n, \r, \t
pub fn escapeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var len: usize = 0;
    for (input) |c| {
        switch (c) {
            '\\', '"', '\n', '\r', '\t' => len += 2,
            else => len += 1,
        }
    }

    var result = try allocator.alloc(u8, len);
    errdefer allocator.free(result);

    var i: usize = 0;
    for (input) |c| {
        switch (c) {
            '\\' => {
                result[i] = '\\';
                result[i + 1] = '\\';
                i += 2;
            },
            '"' => {
                result[i] = '\\';
                result[i + 1] = '"';
                i += 2;
            },
            '\n' => {
                result[i] = '\\';
                result[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                result[i] = '\\';
                result[i + 1] = 'r';
                i += 2;
            },
            '\t' => {
                result[i] = '\\';
                result[i + 1] = 't';
                i += 2;
            },
            else => {
                result[i] = c;
                i += 1;
            },
        }
    }

    return result;
}
