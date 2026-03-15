#!/usr/bin/env bash

# State file for tracking view mode
STATE_FILE="/tmp/waybar_network_state"

# Define network name mappings
# Format: "SSID":"DisplayName"
declare -A network_mappings=(
    ["MyHomeWiFi"]="Home"
    ["OfficeWiFi"]="Office"
    ["GuestNetwork"]="Guest"
)

# Define icons (nerdfonts)
WIFI_ICON="󰖩"
LAN_ICON="󰈀"

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

# Function to get network adapter info
get_adapter_info() {
    local adapter="$1"
    local ip_info=$(ip addr show "$adapter" 2>/dev/null | grep "inet " | awk '{print $2}' | head -n1 | tr -d '\n')
    echo "$ip_info"
}

# Function to get WiFi signal strength
get_signal_strength() {
    local adapter="$1"
    local ssid="$2"
    # Get signal strength from currently connected network only
    local signal=$(nmcli -t -f IN-USE,SIGNAL,SSID dev wifi 2>/dev/null | grep "^\*" | grep "$ssid" | cut -d: -f2 | tr -d '\n')
    if [ -z "$signal" ]; then
        # Fallback to the first matching network if connected one not found
        signal=$(nmcli -t -f SSID,SIGNAL dev wifi 2>/dev/null | grep "^$ssid:" | cut -d: -f2 | head -n1 | tr -d '\n')
    fi
    echo "$signal"
}

# Handle command line arguments
if [ "$1" = "toggle" ]; then
    toggle_view
    exit 0
fi

# Get current view mode
view_mode=$(get_view_mode)

# Check network status
wifi_connected=false
lan_connected=false
current_ssid=""
adapter_name=""
ip_address=""

# Check for WiFi connection
if command -v nmcli &> /dev/null; then
    # Get the currently connected WiFi network
    connected_wifi=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | grep "wifi:connected" | head -n1)
    if [ -n "$connected_wifi" ]; then
        wifi_connected=true
        adapter_name=$(echo "$connected_wifi" | cut -d: -f1)
        # Get the SSID of the connected network
        current_ssid=$(nmcli -t -f NAME connection show --active 2>/dev/null | head -n1)
        ip_address=$(get_adapter_info "$adapter_name")
    fi
fi

# Check for LAN connection
if [ -z "$ip_address" ]; then
    lan_adapters=$(ip link show 2>/dev/null | grep "state UP" | grep -E "^(eth|enp|eno)" | awk -F: '{print $2}' | tr -d ' ')
    for adapter in $lan_adapters; do
        # Skip virtual interfaces (veth, docker, bridge interfaces)
        if [[ "$adapter" != veth* && "$adapter" != docker* && "$adapter" != br-* ]]; then
            adapter_ip=$(get_adapter_info "$adapter")
            if [ -n "$adapter_ip" ]; then
                lan_connected=true
                adapter_name="$adapter"
                ip_address="$adapter_ip"
                break
            fi
        fi
    done
fi

if [ "$wifi_connected" = true ] || [ "$lan_connected" = true ]; then
    # Determine display name
    display_name=""
    
    if [ "$wifi_connected" = true ]; then
        # Check if this SSID matches any of our mappings
        for ssid in "${!network_mappings[@]}"; do
            if [[ "$current_ssid" == *"$ssid"* ]]; then
                display_name="${network_mappings[$ssid]}"
                break
            fi
        done
        
        # If no mapping found, use the SSID (truncated if too long)
        if [ -z "$display_name" ]; then
            if [ ${#current_ssid} -gt 12 ]; then
                display_name="${current_ssid:0:12}…"
            else
                display_name="$current_ssid"
            fi
        fi
        
        icon="$WIFI_ICON"
        connection_type="WiFi"
    else
        display_name="LAN"
        icon="$LAN_ICON"
        connection_type="Ethernet"
    fi
    
    # Prepare tooltip with detailed info (use full network name, not truncated)
    tooltip_network_name="$current_ssid"
    tooltip_info="Network: $tooltip_network_name\n$connection_type: $adapter_name\nIP: $ip_address"
    
    # Add signal strength for WiFi connections
    if [ "$wifi_connected" = true ]; then
        signal_strength=$(get_signal_strength "$adapter_name" "$current_ssid")
        if [ -n "$signal_strength" ]; then
            tooltip_info="$tooltip_info\nSignal: $signal_strength%"
        fi
    fi
    
    if [ "$view_mode" = "full" ]; then
        # Full view: show network name with icon on the right
        echo "{\"text\":\"$display_name $icon\",\"tooltip\":\"$tooltip_info\"}"
    else
        # Compact view: just show icon
        echo "{\"text\":\"$icon\",\"tooltip\":\"$tooltip_info\"}"
    fi
else
    # No network connection
    echo "{\"text\":\"󰖪\",\"tooltip\":\"No network connection\"}"
fi