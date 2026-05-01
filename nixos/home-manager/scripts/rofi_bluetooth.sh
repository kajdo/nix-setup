#!/usr/bin/env bash

# Get paired devices and format for rofi (Name [MAC])
devices=$(echo "devices" | bluetoothctl --timeout 2 | sed 's/\x1b\[[0-9;]*m//g' | grep "^Device" | awk '{name=""; for(i=3;i<=NF;i++) name=name" "$i; print name " [" $2 "]"}')

# Show rofi menu and get selected device
selected=$(echo "$devices" | rofi -dmenu -i -p "Bluetooth Device")

# Extract MAC address from selection (remove brackets and spaces)
mac=$(echo "$selected" | grep -oP '(?<=\[)[^]]+(?=\])')

# If a device was selected, connect to it
if [[ -n "$mac" ]]; then
    echo "connect $mac" | bluetoothctl --timeout 5
    notify-send "Bluetooth Connected" "Device $selected connected"
fi
