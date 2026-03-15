#!/usr/bin/env bash

# start sxhkd for keyboard shortcuts
sxhkd &

# start picom for transparancy
set_random_wallpaper.sh &

# start dwmblocks
dwmblocks &

# start compositor
picom --config ~/.config/picom/picom.conf -b

# start dunst
dunst &

# hide mousecursor if not needed
unclutter --timeout 1 &

# start blueman-applet
# blueman-applet &

# start nm-applet
nm-applet &

# clipboard manager
clipit &
