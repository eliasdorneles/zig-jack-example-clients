const std = @import("std");
const c = @cImport(@cInclude("jack/jack.h"));
const print = std.debug.print;

const math = std.math;

const TABLE_SIZE = 200;

var output_port1: ?*c.jack_port_t = undefined;
var output_port2: ?*c.jack_port_t = undefined;

var sine_table: [TABLE_SIZE]f32 = undefined;

var left_phase: u8 = 0;
var right_phase: u8 = 0;

fn process(nframes: c.jack_nframes_t, arg: ?*anyopaque) callconv(.C) c_int {
    _ = arg;
    var out1_pointer: [*]f32 = @ptrCast(@alignCast(c.jack_port_get_buffer(output_port1, nframes)));
    const out1 = out1_pointer[0..nframes];
    var out2_pointer: [*]f32 = @ptrCast(@alignCast(c.jack_port_get_buffer(output_port2, nframes)));
    const out2 = out2_pointer[0..nframes];
    const volume = 0.2;

    for (out1, out2) |*left, *right| {
        left.* = volume * sine_table[left_phase];
        right.* = volume * sine_table[right_phase];
        left_phase += 1;
        right_phase += 3;
        if (left_phase >= TABLE_SIZE) {
            left_phase -= TABLE_SIZE;
        }
        if (right_phase >= TABLE_SIZE) {
            right_phase -= TABLE_SIZE;
        }
    }

    return 0;
}

fn statusMatch(status: c.jack_status_t, flag: c.jack_status_t) bool {
    return (status & flag) != 0;
}

pub fn main() !void {
    // Fill the table with sine values
    for (&sine_table, 0..) |*item, i| {
        item.* = math.sin((@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(TABLE_SIZE))) * 2.0 * math.pi);
    }

    var jack_status: c.jack_status_t = undefined;
    const client = c.jack_client_open("sine_client", c.JackNullOption, &jack_status);
    if (client == null) {
        print("Failed to open client, status={}\n", .{jack_status});
        if (statusMatch(jack_status, c.JackServerFailed)) {
            print("Unable to connect to JACK server\n", .{});
        }
        std.process.exit(1);
    }
    if (statusMatch(jack_status, c.JackServerStarted)) {
        print("JACK server started\n", .{});
    }
    if (statusMatch(jack_status, c.JackNameNotUnique)) {
        const client_name = c.jack_get_client_name(client);
        print("Unique name `{}` assigned\n", .{client_name.*});
    }
    print("Client opened\n", .{});
    defer {
        _ = c.jack_client_close(client);
        print("Client closed\n", .{});
        std.process.exit(0);
    }

    _ = c.jack_set_process_callback(client, process, null);

    // register two output ports
    output_port1 = c.jack_port_register(
        client,
        "output1",
        c.JACK_DEFAULT_AUDIO_TYPE,
        c.JackPortIsOutput,
        0,
    );
    output_port2 = c.jack_port_register(
        client,
        "output2",
        c.JACK_DEFAULT_AUDIO_TYPE,
        c.JackPortIsOutput,
        0,
    );

    if (output_port1 == null or output_port2 == null) {
        print("Failed to create ports\n", .{});
        std.process.exit(1);
    }

    // from here on, JACK will start calling the process callback
    if (c.jack_activate(client) != 0) {
        print("Failed to activate client\n", .{});
        _ = c.jack_client_close(client);
        std.process.exit(1);
    }

    // connect the ports -- cannot be done before the client is activated
    // note: we connect this program output ports to jack's physical input ports
    {
        const input_ports: [*c][*c]const u8 = c.jack_get_ports(client, null, null, c.JackPortIsPhysical | c.JackPortIsInput);
        defer c.jack_free(@ptrCast(input_ports));

        if (input_ports == null) {
            print("No physical input ports\n", .{});
        }
        if (c.jack_connect(client, c.jack_port_name(output_port1), input_ports[0]) != 0) {
            print("Failed to connect output port\n", .{});
        }
        if (c.jack_connect(client, c.jack_port_name(output_port2), input_ports[1]) != 0) {
            print("Failed to connect output port\n", .{});
        }
    }

    print("Hit Ctrl-C to stop\n", .{});
    while (true) {
        std.time.sleep(std.time.ns_per_s);
    }
}
