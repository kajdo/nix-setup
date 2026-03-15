#!/usr/bin/env bash

# Get connected Bluetooth devices with battery levels
connected_devices=$(bluetoothctl devices Connected | while read -r _ mac name; do
    battery_level=$(bluetoothctl info "$mac" | grep "Battery Percentage" | awk -F '[()]' '{print $2}')
    if [[ -n "$battery_level" ]]; then
        echo "$name $battery_level%"
    else
        echo "$name"
    fi
done)

# If no devices are connected, show a notification and exit
if [[ -z "$connected_devices" ]]; then
    notify-send "Bluetooth Info" "No devices currently connected"
    exit 0
fi

# Show rofi menu and get selected device
selected=$(echo "$connected_devices" | rofi -dmenu -i -p "Select Bluetooth Device")

echo "selected: $selected"

# Extract device name by removing battery percentage
device_name=$(echo "$selected" | sed 's/ [0-9]\+%$//')
echo "Device name: $device_name"

# Extract MAC address using grep and awk
mac=$(bluetoothctl devices Connected | grep "$device_name" | awk '{print $2}')
echo "mac selected: $mac"

# If a device was selected, handle profile selection and battery level
if [[ -n "$mac" ]]; then

    # Get available profiles between Profile: and Aktives Profil
    profiles=$(pactl list cards | awk -v mac="$mac" '
        /bluez5.address = "'"$mac"'"/ {start=1}
        start && /Profile:/ {profile_section=1}
        profile_section && /Aktives Profil:/ {exit}
        profile_section && /:/ {print $1}
    ' | tr -d ':')
    echo "profiles: $profiles"

    # Get current profile
    current_profile=$(pactl list cards | grep -A35 "bluez5.address = \"$mac\"" | grep "Aktives Profil:" | awk '{print $3}')

    # Create profile options with current profile marked
    profile_options=""
    for profile in $profiles; do
        if [[ "$profile" == "$current_profile" ]]; then
            profile_options+="$profile *current*\n"
        else
            profile_options+="$profile\n"
        fi
    done

    # Show profile selection menu
    selected_profile=$(echo -e "$profile_options" | rofi -dmenu -i -p "Select Profile")

    # Extract just the profile name (remove *current* marker)
    selected_profile=$(echo "$selected_profile" | awk '{print $1}')

    # Get the Bluetooth sink name
    bluetooth_sink=$(pactl list cards short | grep "bluez" | awk '{print $1}')

    echo "Bluetooth_sink: $bluetooth_sink selected_profile: $selected_profile"
    # If a different profile was selected, switch to it
    if [[ -n "$selected_profile" && "$selected_profile" != "$current_profile" ]]; then
        pactl set-card-profile "$bluetooth_sink" "$selected_profile"
        notify-send "Bluetooth Profile Changed" "Switched to $selected_profile"
    fi
fi
