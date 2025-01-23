const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("jack/jack.h");
    @cInclude("jack/midiport.h");
    @cInclude("sndfile.h");
});

var PROGRAM_NAME: []const u8 = undefined;

const USAGE_FMT =
    \\Usage: {s} [-B buf_size] [-o OUT_WAV_FILE] DURATION PORT1 [PORT2]...
    \\
    \\Options:
    \\  -B buf_size    Buffer size in bytes (default: 16384)
    \\  -o OUT_WAV_FILE  Output WAV file path (default: wave_out.wav)
    \\  -v             Verbose output
    \\
    \\Arguments:
    \\  DURATION       Duration in seconds
    \\  port1 [ port2 ... ]  List of ports
    \\
    \\
;

// CLI options
const CliArgs = struct {
    verbose: bool = false,
    buf_size: u32 = 16384,
    output_path: []const u8 = "wave_out.wav",
    duration: u32 = 0,
    ports: [][]u8 = undefined,
};

fn display_usage() void {
    print(USAGE_FMT, .{PROGRAM_NAME});
}

const ArgParseError = error{ MissingArgs, InvalidArgs };

fn parseArgs(argv: [][]u8) ArgParseError!CliArgs {
    PROGRAM_NAME = std.fs.path.basename(argv[0]);
    var args = CliArgs{};

    // parse optional arguments i.e. anything that start with a dash '-'
    var optind: usize = 1;
    while (optind < argv.len and argv[optind][0] == '-') {
        if (std.mem.eql(u8, argv[optind], "-v")) {
            args.verbose = true;
        } else if (std.mem.eql(u8, argv[optind], "-B")) {
            if (optind + 1 >= argv.len) {
                display_usage();
                return error.MissingArgs;
            }
            optind += 1;
            args.buf_size = std.fmt.parseInt(u32, argv[optind], 10) catch {
                display_usage();
                print("Invalid buffer size: '{s}'\n", .{argv[optind]});
                return error.InvalidArgs;
            };
        } else if (std.mem.eql(u8, argv[optind], "-o")) {
            if (optind + 1 >= argv.len) {
                display_usage();
                return error.MissingArgs;
            }
            optind += 1;
            args.output_path = argv[optind];
        } else {
            display_usage();
            print("Unknown option: {s}\n", .{argv[optind]});
            return error.InvalidArgs;
        }
        optind += 1;
    }

    // validate and parse positional arguments
    if (argv.len - optind < 2) {
        display_usage();
        return error.MissingArgs;
    }

    args.duration = std.fmt.parseInt(u32, argv[optind], 10) catch {
        display_usage();
        print("Invalid duration: '{s}'\n", .{argv[optind]});
        return error.InvalidArgs;
    };
    optind += 1;

    args.ports = argv[optind..];

    return args;
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args = parseArgs(argv) catch {
        return 1;
    };

    // print parsed arguments
    print("Verbose: {}\n", .{args.verbose});
    print("Output path: {s}\n", .{args.output_path});
    print("Duration: {d} seconds\n", .{args.duration});
    print("Buffer size: {}\n", .{args.buf_size});
    for (args.ports, 1..) |port, n_port| {
        print("Port {d}: {s}\n", .{ n_port, port });
    }
    return 0;
}
