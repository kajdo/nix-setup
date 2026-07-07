#!/usr/bin/env bash
# Event-driven network widget for waybar (continuous mode).
# One long-lived `nmcli monitor` coproc per watch — re-renders only on real
# NetworkManager state-change events (~0 % idle CPU, instant updates).
# No leader/flock/cache: `nmcli` has no single-session/agent conflict (unlike
# bluetoothctl's one-agent-only rule), so each watch runs its own monitor and
# there is nothing to elect. Two coexist fine.
# Signal % read from nmcli (parity with the previous widget) — NOT from
# /proc/net/wireless: they are different data sources (mac80211 link quality vs
# NetworkManager's AP Strength from wpa_supplicant) and no derivation from
# /proc/net/wireless can reproduce nmcli's displayed value.
# A periodic ~15 s refresh covers signal/lease drift that does not fire events.

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/kajdo/bin${PATH:+:$PATH}"

RT="${XDG_RUNTIME_DIR:-/tmp}"
VIEWFILE="$RT/waybar_net_view"   # view mode: full|compact (default compact)
REFRESH=15                       # seconds: periodic re-render for signal drift

# Define network name mappings
# Format: "SSID":"DisplayName"
declare -A network_mappings=(
    ["MyHomeWiFi"]="Home"
    ["OfficeWiFi"]="Office"
    ["GuestNetwork"]="Guest"
)

# Define icons (nerdfonts) — byte-exact glyphs, do NOT retype
WIFI_ICON="󰖩"
LAN_ICON="󰈀"
DISCONNECTED_ICON="󰖪"

# --- Helper functions ---

# Read the current view mode from VIEWFILE (fork-free — no cat).
# Called every loop tick, so must not spawn a subprocess.
get_view_mode() {
    local m="compact"
    [ -r "$VIEWFILE" ] && read -r m < "$VIEWFILE" 2>/dev/null
    printf '%s' "$m"
}

# Escape a string for safe inclusion in JSON.
# Reads from stdin; backslash-escapes \ first, then ".
# Test: printf 'a"b\c' | escape_json  =>  a\"b\\c
escape_json() {
    local s
    s=$(cat)
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s\n' "$s"
}

# Read the connected AP's signal strength from nmcli (same source as the
# previous widget, so the displayed % is guaranteed to match).
# Parameterless — nmcli's IN-USE:* identifies the connected network.
# Empty string if not on wifi.
get_signal_pct() {
    nmcli -t -f IN-USE,SIGNAL,SSID dev wifi 2>/dev/null \
        | awk -F: '$1=="*"{print $2; exit}'
}

# Return the first IPv4 address (with CIDR) for the given interface.
get_adapter_ip() {
    ip -4 addr show dev "$1" 2>/dev/null \
        | awk '/inet /{print $2; exit}'
}

# Check whether the nmcli monitor coproc is still running.
coproc_alive() {
    [ -n "${NMC_PID:-}" ] && kill -0 "$NMC_PID" 2>/dev/null
}

# --- State refresh (detail queries — only on events or periodic tick) ---

# Query NetworkManager and/or ip for current connection state.
# Sets globals: NET_KIND, SSID, ADAPTER, IP, SIGNAL, DISPLAY_NAME.
refresh_state() {
    NET_KIND="none"; SSID=""; ADAPTER=""; IP=""; SIGNAL=""; DISPLAY_NAME=""

    # --- LAN first: a real wired ethernet interface with an IP wins over WiFi.
    # Matches the "plug in a cable -> show the cable" expectation; wired is
    # normally the preferred (lower-metric) path when both links are up.
    local iface
    while IFS= read -r line; do
        # Interface name is the second colon-separated field in "ip -o" output
        iface="${line#*: }"
        iface="${iface%%:*}"
        # Must be an ethernet name; skip virtual interfaces
        case "$iface" in
            veth*|docker*|br-*) continue ;;
        esac
        case "$iface" in
            eth*|enp*|eno*) ;;
            *) continue ;;
        esac
        local iface_ip
        iface_ip=$(get_adapter_ip "$iface")
        if [ -n "$iface_ip" ]; then
            ADAPTER="$iface"
            IP="$iface_ip"
            NET_KIND="lan"
            SSID=""
            break
        fi
    done < <(ip -o link show up 2>/dev/null)

    # --- WiFi (only if no wired connection with an IP) ---
    if [ "$NET_KIND" != "lan" ] && command -v nmcli &>/dev/null; then
        local wifi_line
        wifi_line=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null \
            | grep 'wifi:connected' | head -n1)
        if [ -n "$wifi_line" ]; then
            ADAPTER="${wifi_line%%:*}"
            local conn_line
            conn_line=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
                | awk -F: -v dev="$ADAPTER" '$2==dev{print $1; exit}')
            if [ -n "$conn_line" ]; then
                SSID="$conn_line"
                IP=$(get_adapter_ip "$ADAPTER")
                SIGNAL=$(get_signal_pct)
                NET_KIND="wifi"
            fi
        fi
    fi

    # --- Display-name mapping ---
    if [ -n "$SSID" ]; then
        for key in "${!network_mappings[@]}"; do
            if [[ "$SSID" == *"$key"* ]]; then
                DISPLAY_NAME="${network_mappings[$key]}"
                break
            fi
        done
        if [ -z "$DISPLAY_NAME" ]; then
            if [ "${#SSID}" -gt 12 ]; then
                DISPLAY_NAME="${SSID:0:12}…"   # truncate + ellipsis (U+2026)
            else
                DISPLAY_NAME="$SSID"
            fi
        fi
    fi
}

# --- Render (single JSON line to stdout) ---

# Build one JSON line from the current globals and emit it.
# One line = one waybar update.  Text and tooltip values are routed
# through escape_json so SSIDs containing " or \ can't break the output.
render() {
    local view text tooltip
    view=$(get_view_mode)

    if [ "$NET_KIND" = "none" ]; then
        text="$DISCONNECTED_ICON"
        tooltip="No network connection"

    elif [ "$NET_KIND" = "lan" ]; then
        if [ "$view" = "full" ]; then
            text="LAN $LAN_ICON"
        else
            text="$LAN_ICON"
        fi
        tooltip="Network:\nEthernet: $(escape_json <<< "$ADAPTER")\nIP: $(escape_json <<< "$IP")"

    elif [ "$NET_KIND" = "wifi" ]; then
        if [ "$view" = "full" ]; then
            text="$(escape_json <<< "$DISPLAY_NAME") $WIFI_ICON"
        else
            text="$WIFI_ICON"
        fi
        tooltip="Network: $(escape_json <<< "$SSID")\nWiFi: $(escape_json <<< "$ADAPTER")\nIP: $(escape_json <<< "$IP")"
        if [ -n "$SIGNAL" ]; then
            tooltip="$tooltip\nSignal: $(escape_json <<< "$SIGNAL")%"
        fi
    fi

    printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$tooltip"
}

# --- Toggle subcommand + signal-safe flag handling ---

# Handle "toggle" argument (flips view between full and compact).
# This block runs at script-execution time, AFTER all function definitions
# and BEFORE the main loop (Task 7).  Exiting here prevents the long-
# lived nmcli monitor from starting — the caller (waybar on-click) just
# wants the view flipped, not a new watch process.
if [ "${1:-}" = "toggle" ]; then
    cur=""
    [ -r "$VIEWFILE" ] && read -r cur < "$VIEWFILE" 2>/dev/null
    if [ "$cur" = "full" ]; then
        printf 'compact' > "$VIEWFILE"
    else
        # Absent or compact → write full (matches original default)
        printf 'full' > "$VIEWFILE"
    fi
    # Best-effort: signal running watches to re-render immediately.
    # The $-anchor excludes this toggle process and the exec'd nmcli coproc.
    pkill -USR1 -f '/waybar/network\.sh$' 2>/dev/null || true
    exit 0
fi

# USR1 handler: sets ONLY a flag (TRIGGER=1).  The main loop checks
# this flag each tick and re-renders if set.  NEVER use trap 'render' USR1
# — that was the bluetooth loop-kill bug (signal interrupts blocking read,
# the read returns non-zero, and the while-loop exits, killing the watch).
trap 'TRIGGER=1' USR1

# --- Event-driven main loop (one long-lived nmcli monitor per watch) ---

# Teardown: kill the coproc subtree so no orphaned nmcli monitor accumulates
# across waybar restarts.  The `exec` inside the coproc means NMC_PID IS the
# nmcli process itself (not a bash subshell), so `kill $NMC_PID` is direct.
trap '[ -n "${NMC_PID:-}" ] && { pkill -P "$NMC_PID" 2>/dev/null; kill "$NMC_PID" 2>/dev/null; }' EXIT

# Start the monitor.  `exec` replaces the coproc subshell with nmcli itself,
# so its cmdline reads "nmcli monitor" (not this script) — keeps pgrep clean.
coproc NMC { exec nmcli monitor 2>/dev/null; }
[ -n "${NMC[0]:-}" ] || { sleep 2; exit 1; }

# Drain the startup banner ("NetworkManager is running"), then query state
# with a brief retry in case NM is still initialising.
# BOUNDED drain of the startup banner (at most a few lines) — a flood of early
# NM events must not be able to trap the loop here before the first paint.
for _ in 1 2 3 4 5; do
    coproc_alive || exit 0
    IFS= read -r -t 0.3 _ <&"${NMC[0]}" 2>/dev/null || break
done
for _ in 1 2 3; do
    coproc_alive || exit 0
    refresh_state
    [ "$NET_KIND" != "none" ] && break
    sleep 0.5
done
coproc_alive || exit 0
render
last_render=${EPOCHSECONDS:-0}

# Follow NetworkManager events.  Re-render on any monitor output (drain the
# burst first, then query once).  Also re-render on view toggle (USR1 flag)
# and on a periodic timer for signal / DHCP-lease drift.
TRIGGER=0
last_view="$(get_view_mode)"

while coproc_alive; do
    if IFS= read -r -t 1 line <&"${NMC[0]}" 2>/dev/null; then
        # NM emits a burst of lines per state change — drain them all,
        # then re-query once and re-render.
        # Coalesce the burst into one refresh — BOUNDED (<=10 lines, 0.1s gaps)
        # so a continuous event flood can never trap the loop here.
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            IFS= read -r -t 0.1 _ <&"${NMC[0]}" 2>/dev/null || break
        done
        coproc_alive || exit 0
        refresh_state
        render
        last_render=${EPOCHSECONDS:-0}
    fi

    # View toggled (USR1 flag or out-of-band VIEWFILE change) → re-render.
    v="$(get_view_mode)"
    if (( TRIGGER )) || [ "$v" != "$last_view" ]; then
        TRIGGER=0
        last_view="$v"
        render
    fi

    # Periodic refresh: signal drift and DHCP lease changes don't fire
    # nmcli monitor events, so re-query every REFRESH seconds.
    if (( ${EPOCHSECONDS:-0} - last_render >= REFRESH )); then
        refresh_state
        render
        last_render=${EPOCHSECONDS:-0}
    fi
done
exit 0
