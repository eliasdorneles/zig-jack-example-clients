# Zig + JACK code examples

I am porting some example clients from [JACK example
clients](https://github.com/jackaudio/jack-example-tools/tree/main/example-clients)
to Zig.


## How to run

First, install the JACK development libraries.
In Ubuntu, you can do this by: `sudo apt install libjack-jackd2-dev`.

You need to be running either JACK or Pipewire.
This is the case on Ubuntu since 22.10.

Then, run with: `zig run simple_client.zig -lc -ljack`
