#!/bin/bash

outfile=out-$(date +'%Y_%m_%d__%H%M_%S').wav

# run capture_client program, using jack_lsp to get the list of capture ports
eval ./capture_client -v -o "$outfile" 2 \
    $(jack_lsp | grep Stereo:capture | while read line; do echo \"$line\"; done)
