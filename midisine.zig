const std = @import("std");
const c = @cImport({
    @cInclude("jack/jack.h");
    @cInclude("jack/midiport.h");
});
const print = std.debug.print;

const math = std.math;

var client: ?*c.jack_client_t = undefined;
var input_port: ?*c.jack_port_t = undefined;
var output_port: ?*c.jack_port_t = undefined;

// This will store values per each MIDI note that we'll use later to generate
// the sine wave.
// The values here will represent the necessary increments for each sample in
// order to generate the desired frequency for the currently playing note.
var note_freqs: [128]f32 = undefined;

// these will be updated by the process callback
var ramp: f32 = 0.0;
var note_on: f32 = 0.0;
var note: u8 = 0;

fn calc_note_freqs(sample_rate: u32) void {
    for (&note_freqs, 0..) |*item, i| {
        item.* = 440.0 / 16.0 * math.pow(f32, 2.0, (@as(f32, @floatFromInt(i)) - 9.0) / 12.0) / @as(f32, @floatFromInt(sample_rate));
    }
}

fn sample_rate_callback(nframes: c.jack_nframes_t, arg: ?*anyopaque) callconv(.C) c_int {
    _ = arg;
    calc_note_freqs(nframes);
    return 0;
}

fn process(nframes: c.jack_nframes_t, arg: ?*anyopaque) callconv(.C) c_int {
    _ = arg;
    var out_pointer: [*]f32 = @ptrCast(@alignCast(c.jack_port_get_buffer(output_port, nframes)));
    const out = out_pointer[0..nframes];

    const port_buf = c.jack_port_get_buffer(input_port, nframes);
    var in_event: c.jack_midi_event_t = undefined;

    const event_count = c.jack_midi_get_event_count(port_buf);
    if (event_count > 0) {
        print("event_count = {d}\n", .{event_count});
    }

    var event_index: u32 = 0;

    // load the first event...
    _ = c.jack_midi_event_get(&in_event, port_buf, 0);
    // ...and then iterate over all frames
    for (out, 0..) |*audio_chan, i| {
        if (in_event.time == i and event_index < event_count) {
            const event_data = in_event.buffer;
            if (event_data[0] == 0x90) {
                // note on event
                note = event_data[1];
                note_on = 1.0;
                // TODO: handle velocity from event_data[2]
            } else if (event_data[0] == 0x80) {
                // note off event
                note = event_data[1];
                note_on = 0.0;
            }
            print("    note {} {s}\n", .{ note, (if (note_on > 0) "on" else "off") });
            event_index += 1;
            if (event_index < event_count) {
                // load the next event
                _ = c.jack_midi_event_get(&in_event, port_buf, event_index);
            }
        }
        ramp += note_freqs[note];
        ramp = if (ramp > 1.0) ramp - 2.0 else ramp;

        audio_chan.* = note_on * @sin(2 * std.math.pi * ramp);
    }
    return 0;
}

pub fn main() !void {
    client = c.jack_client_open("sine_client", c.JackNullOption, null);
    if (client == null) {
        print("Failed to connect to JACK -- is JACK server running?\n", .{});
        std.process.exit(1);
    }
    defer {
        _ = c.jack_client_close(client);
        print("JACK client closed\n", .{});
        std.process.exit(0);
    }

    calc_note_freqs(c.jack_get_sample_rate(client));

    _ = c.jack_set_process_callback(client, process, null);

    _ = c.jack_set_sample_rate_callback(client, sample_rate_callback, null);

    input_port = c.jack_port_register(client, "midi_in", c.JACK_DEFAULT_MIDI_TYPE, c.JackPortIsInput, 0);
    output_port = c.jack_port_register(client, "audio_out", c.JACK_DEFAULT_AUDIO_TYPE, c.JackPortIsOutput, 0);

    if (input_port == null or output_port == null) {
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
        if (c.jack_connect(client, c.jack_port_name(output_port), input_ports[0]) != 0) {
            print("Failed to connect output port\n", .{});
        }
        if (c.jack_connect(client, c.jack_port_name(output_port), input_ports[1]) != 0) {
            print("Failed to connect output port\n", .{});
        }
    }

    print("Hit Ctrl-C to stop\n", .{});
    while (true) {
        std.time.sleep(std.time.ns_per_s);
    }
}
