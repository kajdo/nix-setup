#!/usr/bin/env bash

# State file for tracking view mode
STATE_FILE="/tmp/waybar_bluetooth_state"

# Define device name mappings with battery monitoring preferences
declare -A device_mappings=(
    ["Q20i"]="Q20i:1"       # Q20i with battery monitoring enabled
    ["CMF"]="Buds:1"        # CMF Buds Pro
    ["AirPods"]="AirPods:1" # AirPods with battery monitoring
    ["WH-1000XM4"]="Sony:1" # Sony with battery monitoring
    ["MX Master"]="MX:0"    # MX Master without battery monitoring
    ["Keyboard"]="⌨:0"      # Keyboard without battery monitoring
    ["Mouse"]="🖱:0"         # Mouse without battery monitoring
)

# Function to get battery percentage for a device
get_battery_percentage() {
    local mac="$1"
    # local battery_percent=$(bluetoothctl info "$mac" 2>/dev/null | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d '%')
    local battery_percent=$(bluetoothctl info "$mac" 2>/dev/null | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d '%')
    echo "$battery_percent"
}

# Function to get battery icon based on percentage
get_battery_icon() {
    local battery_percent="$1"
    if [ -z "$battery_percent" ]; then
        echo ""
        return
    fi

    if ((battery_percent < 10)); then
        echo "󰤾"
    elif ((battery_percent < 20)); then
        echo "󰤿"
    elif ((battery_percent < 30)); then
        echo "󰥀"
    elif ((battery_percent < 40)); then
        echo "󰥁"
    elif ((battery_percent < 50)); then
        echo "󰥂"
    elif ((battery_percent < 60)); then
        echo "󰥃"
    elif ((battery_percent < 70)); then
        echo "󰥄"
    elif ((battery_percent < 80)); then
        echo "󰥅"
    elif ((battery_percent < 90)); then
        echo "󰥆"
    else
        echo "󰥈"
    fi
}

# Function to toggle view mode
toggle_view() {
    if [ -f "$STATE_FILE" ]; then
        current_mode=$(cat "$STATE_FILE")
        if [ "$current_mode" = "full" ]; then
            echo "compact" >"$STATE_FILE"
        else
            echo "full" >"$STATE_FILE"
        fi
    else
        echo "full" >"$STATE_FILE"
    fi
}

# Function to get current view mode
get_view_mode() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "compact" # Default to compact view
    fi
}

# Handle command line arguments
if [ "$1" = "toggle" ]; then
    toggle_view
    exit 0
fi

# Get current view mode
view_mode=$(get_view_mode)

# Check if bluetooth is powered on
bluetooth_status=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')

if [ "$bluetooth_status" = "yes" ]; then
    # Get only actual device lines (they start with "Device" and have MAC + name)
    connected_devices=$(bluetoothctl devices Connected 2>/dev/null | grep "^Device" | wc -l)

    if [ "$connected_devices" -gt 0 ]; then
        # Get the first connected device info
        first_device_info=$(bluetoothctl devices Connected 2>/dev/null | grep "^Device" | head -n1)
        first_device_name=$(echo "$first_device_info" | cut -d' ' -f3-)
        first_device_mac=$(echo "$first_device_info" | awk '{print $2}')

        # Check if this device matches any of our mappings
        display_name=""
        monitor_battery=0
        for partial_name in "${!device_mappings[@]}"; do
            if [[ "$first_device_name" == *"$partial_name"* ]]; then
                IFS=':' read -r display_name monitor_battery <<<"${device_mappings[$partial_name]}"
                break
            fi
        done

        # If no mapping found, use the full device name (truncated if too long)
        if [ -z "$display_name" ]; then
            if [ ${#first_device_name} -gt 12 ]; then
                display_name="${first_device_name:0:12}…"
            else
                display_name="$first_device_name"
            fi
            monitor_battery=0 # Don't monitor battery for unknown devices by default
        fi

        # Get battery info if monitoring is enabled for this device
        battery_info=""
        battery_text=""
        if [ "$monitor_battery" -eq 1 ]; then
            battery_percent=$(get_battery_percentage "$first_device_mac")
            if [ -n "$battery_percent" ]; then
                battery_icon=$(get_battery_icon "$battery_percent")
                battery_info=" $battery_icon"
                battery_text=" $battery_percent%"
            fi
        fi

        # Prepare tooltip with full info (always show detailed info in tooltip)
        tooltip_info=""
        if [ "$connected_devices" -eq 1 ]; then
            tooltip_info="$display_name $battery_text$battery_info"
        else
            tooltip_info="$display_name $battery_text$battery_info +$((connected_devices - 1))"
        fi

        # Bluetooth is on and devices are connected
        if [ "$view_mode" = "full" ]; then
            # Full view: show detailed info in DeviceName BluetoothIcon Battery% BatteryIcon format
            if [ "$connected_devices" -eq 1 ]; then
                echo "{\"text\":\"$display_name $battery_text$battery_info\",\"tooltip\":\"$tooltip_info\"}"
            else
                echo "{\"text\":\"$display_name $battery_text$battery_info +$((connected_devices - 1))\",\"tooltip\":\"$tooltip_info\"}"
            fi
        else
            # Compact view: just show device name with icon on the right
            echo "{\"text\":\"$display_name \",\"tooltip\":\"$tooltip_info\"}"
        fi
    else
        # Bluetooth is on but no devices connected
        echo "{\"text\":\"\",\"tooltip\":\"No devices connected\"}"
    fi
else
    # Bluetooth is off
    echo "{\"text\":\"\",\"tooltip\":\"Bluetooth disabled\"}"
fi
