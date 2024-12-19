const std = @import("std");

const program_name = "capture_client";
const errexit = 1;

var verbose = false;
var buf_size: u32 = 16384;
var output_path: []u8 = undefined;
var duration: u32 = 0;
var ports: [][]u8 = undefined;

fn display_usage() void {
    std.debug.print(
        "Usage: {s} [-B buf_size] <output.wav> <duration_in_seconds> port1 [ port2 ... ]\n",
        .{program_name},
    );
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // argument parsing starts here
    var optind: usize = 1;
    while (optind < args.len and args[optind][0] == '-') {
        if (std.mem.eql(u8, args[optind], "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, args[optind], "-B")) {
            if (optind + 1 >= args.len) {
                display_usage();
                std.debug.print("Option -B requires an argument\n", .{});
                return errexit;
            }
            optind += 1;
            buf_size = std.fmt.parseInt(u32, args[optind], 10) catch {
                display_usage();
                std.debug.print("Invalid buffer size: '{s}'\n", .{args[optind]});
                return errexit;
            };
        } else {
            display_usage();
            std.debug.print("Unknown option: {s}\n", .{args[optind]});
            return errexit;
        }
        optind += 1;
    }

    if (args.len - optind < 3) {
        display_usage();
        return errexit;
    }

    output_path = args[optind];
    optind += 1;
    duration = std.fmt.parseInt(u32, args[optind], 10) catch {
        display_usage();
        std.debug.print("Invalid duration: '{s}'\n", .{args[2]});
        return errexit;
    };
    optind += 1;

    ports = args[optind..];
    // ok, we're done with argument parsing

    std.debug.print("Verbose: {}\n", .{verbose});
    std.debug.print("Output path: {s}\n", .{output_path});
    std.debug.print("Duration: {d}\n", .{duration});
    std.debug.print("Buffer size: {}\n", .{buf_size});
    for (ports, 1..) |port, n_port| {
        std.debug.print("Port {d}: {s}\n", .{ n_port, port });
    }
    return 0;
}
