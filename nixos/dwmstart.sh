#!/usr/bin/env bash

# Create a temporary script to launch dwm
echo "exec /run/current-system/sw/bin/dwm" >~/.xinitrc

# Run startx
startx
