const clap = @import("clap");
const std = @import("std");

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

        var response_writer = std.Io.Writer.Allocating.init(allocator);
        defer response_writer.deinit();

        if (res.args.@"list-models" != 0) {
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
            var url_buffer: [64]u8 = undefined;
            const url = try std.fmt.bufPrint(&url_buffer, "{s}/api/chat", .{endpoint});

            var payload = std.Io.Writer.Allocating.init(allocator);
            defer payload.deinit();
            switch (res.args.mode orelse .file) {
                .file => {
                    const system = "You are a cat. Only respond as you would if you were a cat. As you are a cat, you obviously dont speak English, so don't respond using English. You may use onomatopoeia, as well as any other actions. JUST NO SPOKEN ENGLISH. You dont necessarily need to answer the user's question, as long as you act like a cat.";
                    const user = "Why is the sky blue?";
                    try payload.writer.print("{{ \"model\": \"{s}\", \"messages\": [{{ \"role\": \"system\", \"content\": \"{s}\" }}, {{ \"role\": \"user\", \"content\": \"{s}\" }}], \"stream\": false }}", .{ res.args.model.?, system, user });
                },
                else => {},
            }

            const fetch_result = client.fetch(.{
                .location = .{ .url = url },
                .response_writer = &response_writer.writer,
                .payload = payload.written(),
            }) catch |e| {
                std.debug.print("{any}\n", .{e});
                std.process.exit(1);
            };
            _ = fetch_result;
            try out.print("{s}\n", .{response_writer.written()});
            try out.flush();
            return;
        }
    }
    std.debug.print("Unsupported usage.\nUse -h to display help message.\n", .{});
}
