const clap = @import("clap");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const help_message =
        \\-h, --help                    Display this help and exit.
        \\-j, --json                    Formats the output in JSON.
        \\-p, --provider <PROVIDER>     Select between multiple providers. Defaults to ollama.
        \\          ollama
        \\          openrouter
        \\          vscode
        \\-e, --endpoint <STRING>       If provider is Ollama, the endpoint may be specified. Defaults to local.
        \\-l, --list-models             List out each model provided by the selected provider.
        \\-c, --config <FILE>           Specify the config file.
        \\-o, --output <PATH>           Specify the output path.
        \\-M, --max-tokens <INTEGER>    The maximum tokens that a rquest is allowed to consume.
        \\-m, --mode <MODE>             Specify operation mode. Defaults to diff.
        \\          full                Do a full code scan.
        \\          diff                Do a scan over the git diffs.
        \\          spot                Do a spot check on a file.
        \\    --diff <STRING>           If mode is diff, specify a commit to do a diff against.
        \\    --file <FILE>             If mode is spot, specify file for the spot check.
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
        .MODE = clap.parsers.enumeration(enum { full, diff, spot }),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print(help_message, .{});
        return;
    }
    std.debug.print("Unsupported usage.\nUse -h to display help message.\n", .{});
}
