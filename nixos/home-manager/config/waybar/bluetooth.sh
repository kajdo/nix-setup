#!/usr/bin/env bash
#
# Bluetooth widget for waybar — event-driven over D-Bus (leader + cache).
#
# WHY NOT bluetoothctl: bluez 5.86's `bluetoothctl` allocates ~280 MB of heap
# within seconds of startup (a known-bad release; the daemon itself is ~7 MB),
# so a long-lived interactive `bluetoothctl` for the widget burned 280 MB
# constantly. Instead we read BlueZ state straight from D-Bus:
#
#   • The FIRST instance to grab a lock becomes the "leader". It owns the ONE
#     long-lived `dbus-monitor` (a passive ~3 MB signal listener, ~0% idle CPU)
#     and re-queries state via `busctl get-property` only when BlueZ emits a
#     signal (connect/disconnect/battery/alias change), then writes the rendered
#     JSON line to a cache file whenever state changes.
#   • Every other instance is a "follower": it touches neither dbus-monitor nor
#     busctl — it just reads the cache file. Cheap, conflict-free.
#
# Reading BlueZ over D-Bus is radio-free and spawn-light: it never starts
# `bluetoothctl` (no 280 MB, no 30-40% CPU spikes, no agent conflicts) and never
# touches the BT radio (no 2.4 GHz interference with WiFi — the thing that
# stuttered game streaming under the old bluetoothctl polling).
#
#   bluetooth.sh            run watch (becomes leader or follower automatically)
#   bluetooth.sh toggle     flip compact/full view, nudge the leader
#
# Idle cost stays ~0%: the leader only wakes on real BlueZ signals.

# waybar launches us with a minimal environment: no UTF-8 locale (without it
# $'\uXXXX' glyphs render as literal "\uXXXX" text) and a minimal PATH. Fix both.
export LC_ALL=C.UTF-8
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/kajdo/bin${PATH:+:$PATH}"

RT="${XDG_RUNTIME_DIR:-/tmp}"
CACHE="$RT/waybar_bt_cache"    # leader writes one JSON line here; followers read it
VIEWFILE="$RT/waybar_bt_view"  # view mode: full|compact
LOCKFILE="$RT/waybar_bt.lock"  # flock — decides who is leader
PIDFILE="$RT/waybar_bt.pid"    # leader's PID, so toggle can signal it
DEBOUNCE=1                     # seconds of silence that collapse a bluez event burst

# BlueZ lives on the system bus under these well-known names.
BZ=org.bluez
HCI0=/org/bluez/hci0
ADAPTER=org.bluez.Adapter1
DEVICE=org.bluez.Device1
BATTERY=org.bluez.Battery1

# Device name mappings: "name-substring":"display:monitor_battery(0|1)".
declare -A device_mappings=(
	["Q20i"]="Q20i:1"
	["CMF"]="Buds:1"
	["AirPods"]="AirPods:1"
	["WH-1000XM4"]="Sony:1"
	["MX Master"]="MX:0"
	["Keyboard"]=$'\u2328'":0"
	["Mouse"]=$'\U0001f5b1'":0"
)

# ---- helpers ---------------------------------------------------------------

battery_icon() {
	local p="$1"
	[[ "$p" =~ ^[0-9]+$ ]] || { echo ""; return; }
	if   ((p < 10)); then echo $'\U000f093e'
	elif ((p < 20)); then echo $'\U000f093f'
	elif ((p < 30)); then echo $'\U000f0940'
	elif ((p < 40)); then echo $'\U000f0941'
	elif ((p < 50)); then echo $'\U000f0942'
	elif ((p < 60)); then echo $'\U000f0943'
	elif ((p < 70)); then echo $'\U000f0944'
	elif ((p < 80)); then echo $'\U000f0945'
	elif ((p < 90)); then echo $'\U000f0946'
	else echo $'\U000f0948'
	fi
}

get_view_mode() { [ -f "$VIEWFILE" ] && cat "$VIEWFILE" 2>/dev/null || echo "compact"; }

# One BlueZ scalar property via D-Bus. `busctl get-property` prints e.g.
# "b true" / "y 75"; $2 picks the value. Missing interface / error -> empty.
bz_prop() {
	busctl --system get-property "$BZ" "$1" "$2" "$3" 2>/dev/null | awk '{print $2}'
}

# Is the connected BT audio device in a call (HSP/HFP) profile? The audio profile
# is a PipeWire/WirePlumber concept — BlueZ only knows connection, never the
# profile — so we ask PipeWire via pactl. Returns "1" or "0". Single
# `pactl list cards` call; locale forced to C for stable labels.
bt_call_active() {
	LC_ALL=C pactl list cards 2>/dev/null | awk '
		$1 == "Name:" { inbtz = ($2 ~ /^bluez_card/) }
		inbtz && $1 == "Active" && $2 == "Profile:" {
			print ($3 ~ /^headset-head-unit/) ? 1 : 0
			exit
		}
	'
}

# Refresh the ONAIR global from the live BT audio profile.
refresh_onair() {
	ONAIR="$(bt_call_active)"
	[ "$ONAIR" = 1 ] || ONAIR=0
}

# ---- toggle: flip view, then nudge the leader to re-render ----------------
if [ "${1:-}" = toggle ]; then
	if [ "$(get_view_mode)" = full ]; then
		echo "compact" >"$VIEWFILE"
	else
		echo "full" >"$VIEWFILE"
	fi
	lp="$(cat "$PIDFILE" 2>/dev/null)"
	[ -n "$lp" ] && kill -USR1 "$lp" 2>/dev/null
	exit 0
fi

# ---- leader election -------------------------------------------------------
# Try to grab an exclusive lock. The holder is the leader; everybody else is a
# follower. flock auto-releases when the holder dies, so a crashed leader is
# replaced automatically (by a follower's self-heal, below, or by waybar's
# restart-interval respawning a watch).
try_become_leader() {
	exec 9>"$LOCKFILE" 2>/dev/null || return 1
	flock -n 9 2>/dev/null
}

# ---- FOLLOWER: never query D-Bus, just mirror the cache -------------------
if ! try_become_leader; then
	last=""
	while true; do
		# Self-heal: if the leader is gone, try to take over (e.g. leader's bar
		# was closed while another output stayed). Keeps a leader alive as long
		# as ANY watch is running.
		lp="$(cat "$PIDFILE" 2>/dev/null)"
		if { [ -z "$lp" ] || ! kill -0 "$lp" 2>/dev/null; } && try_become_leader; then
			break   # we are now the leader -> fall through to leader code
		fi
		cur=""
		[ -f "$CACHE" ] && IFS= read -r cur <"$CACHE" 2>/dev/null
		if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
			printf '%s\n' "$cur"
			last="$cur"
		fi
		sleep 0.5
	done
fi

# ---- LEADER ---------------------------------------------------------------
# Reaching here means we hold the lock. Write our PID and run the ONE
# dbus-monitor this whole machine will use.

# Globals shared between refresh_state() and render(). ONAIR mirrors the live
# BT audio profile (1 = HSP/HFP call mode) and drives the "on air" CSS class.
POWERED="" DEV_NAME="" DEV_MAC="" DEV_COUNT=0 MON_BATT=0 BATT_PCT="" BATT_ICON=""
ONAIR=0
TRIGGER=0   # set by USR1 (view toggle); the loop re-emits at the next safe point

printf '%s\n' "$$" >"$PIDFILE"

# Teardown: kill the coproc subtree + drop the PIDfile. flock auto-releases.
trap '[ -n "${BCC_PID:-}" ] && { pkill -P "$BCC_PID" 2>/dev/null; kill "$BCC_PID" 2>/dev/null; }; rm -f "$PIDFILE" 2>/dev/null' EXIT
# View toggle: just set a flag (rendering inside the trap is unsafe mid-read).
trap 'TRIGGER=1' USR1

# `exec` replaces the coproc subshell with dbus-monitor itself: its cmdline then
# reads "dbus-monitor" (not this script), so `pgrep bluetooth.sh` shows a clean
# 2 watches, and killing BCC_PID hits dbus-monitor directly. The match filter
# restricts the stream to org.bluez signals only (verified: non-bluez traffic
# does not leak through), so the leader wakes only on real BlueZ events.
coproc BCC { exec dbus-monitor --system "type='signal',sender='org.bluez'" 2>/dev/null; }
[ -n "${BCC[0]:-}" ] || { sleep 2; exit 1; }

coproc_alive() { [ -n "${BCC_PID:-}" ] && kill -0 "$BCC_PID" 2>/dev/null; }

# Read everything the dbus-monitor stream emits until $1 seconds of silence.
drain_bt() {
	local timeout="${1:-0.6}" l
	while IFS= read -r -t "$timeout" l <&"${BCC[0]}" 2>/dev/null; do :; done
}

# ---- state query (ground truth; called only on change) --------------------
# All info comes from BlueZ over D-Bus — no bluetoothctl. ~one busctl call per
# known device; called only on a debounced state change, so the spawn cost is
# negligible and purely radio-free.
refresh_state() {
	local tree dev conn name disp mon pct ellipsis first_dev

	# Adapter Powered ("b true"/"b false") -> normalize to yes/no for render().
	POWERED="$(bz_prop "$HCI0" "$ADAPTER" Powered)"
	[ "$POWERED" = true ] && POWERED=yes || POWERED=no

	if [ "$POWERED" != yes ]; then
		DEV_COUNT=0 DEV_NAME="" DEV_MAC="" MON_BATT=0 BATT_PCT="" BATT_ICON=""
		return
	fi

	# Enumerate known device objects, count connected ones, remember the first
	# (the one we display). Process substitution so the loop body can set globals.
	tree="$(busctl --system tree "$BZ" 2>/dev/null)"
	DEV_COUNT=0
	first_dev=""
	while IFS= read -r dev; do
		[ -n "$dev" ] || continue
		conn="$(bz_prop "$dev" "$DEVICE" Connected)"
		if [ "$conn" = true ]; then
			DEV_COUNT=$((DEV_COUNT + 1))
			[ -z "$first_dev" ] && first_dev="$dev"
		fi
	# Anchor to a full 17-char MAC (XX_XX_XX_XX_XX_XX) at END of line: a connected
	# device also exposes sub-objects (A2DP /fd0, /sep*, GATT services), and a
	# plain prefix match would count the device once per sub-object.
	done < <(printf '%s\n' "$tree" | grep -oE '/org/bluez/hci0/dev_[0-9A-Fa-f_]{17}$')

	if [ "$DEV_COUNT" -eq 0 ] || [ -z "$first_dev" ]; then
		DEV_NAME="" DEV_MAC="" MON_BATT=0 BATT_PCT="" BATT_ICON=""
		return
	fi

	# First connected device: derive MAC from the object path, read its alias.
	# (Alias is the user-facing name; the mappings match against it.)
	DEV_MAC="$(printf '%s\n' "$first_dev" | sed 's#.*/dev_##; s/_/:/g')"
	name="$(busctl --system get-property "$BZ" "$first_dev" "$DEVICE" Alias 2>/dev/null | awk -F'"' '{print $2}')"

	disp="" mon=0
	for k in "${!device_mappings[@]}"; do
		if [[ "$name" == *"$k"* ]]; then
			IFS=':' read -r disp mon <<<"${device_mappings[$k]}"
			break
		fi
	done
	if [ -z "$disp" ]; then
		disp="$name"
		if ((${#disp} > 12)); then
			ellipsis=$'\u2026'
			disp="${disp:0:12}$ellipsis"
		fi
		mon=0
	fi
	DEV_NAME="$disp"
	MON_BATT="$mon"

	# Battery (only for devices the mapping flags as monitorable). The Battery1
	# interface exists only while a device reports battery; get-property errors
	# -> empty -> no battery shown.
	BATT_PCT="" BATT_ICON=""
	if [ "$MON_BATT" = 1 ]; then
		pct="$(bz_prop "$first_dev" "$BATTERY" Percentage)"
		if [[ "$pct" =~ ^[0-9]+$ ]]; then
			BATT_PCT="$pct"
			BATT_ICON="$(battery_icon "$pct")"
		fi
	fi
}

# ---- render: build JSON from globals+view, emit to stdout AND cache --------
render() {
	local mode bt off_nd on_no batt_text batt_info tooltip text json cls
	bt=$'\uf293'     # bluetooth glyph next to the device
	off_nd=$'\uf294' # powered on, nothing connected
	on_no=$'\uf297'  # powered off
	mode="$(get_view_mode)"

	# The "on air" (HSP/HFP) flag drives the CSS class. Refreshed on every paint
	# so the widget always reflects the live PipeWire profile: it flips red on our
	# F9 call-prep toggle and back to blue on WirePlumber's automatic A2DP revert.
	refresh_onair
	cls=""
	[ "$ONAIR" = 1 ] && [ "$POWERED" = yes ] && [ "$DEV_COUNT" -gt 0 ] && cls="onair"

	if [ "$POWERED" != yes ]; then
		json=$(printf '{"text":"%s","tooltip":"Bluetooth disabled","class":"%s"}' "$on_no" "$cls")
	elif [ "$DEV_COUNT" -eq 0 ]; then
		json=$(printf '{"text":"%s","tooltip":"No devices connected","class":"%s"}' "$off_nd" "$cls")
	else
		batt_text="" batt_info=""
		if [ -n "$BATT_PCT" ]; then
			batt_text=" $BATT_PCT%"
			batt_info=" $BATT_ICON"
		fi
		if [ "$DEV_COUNT" -eq 1 ]; then
			tooltip="$DEV_NAME $bt$batt_text$batt_info"
		else
			tooltip="$DEV_NAME $bt$batt_text$batt_info +$((DEV_COUNT - 1))"
		fi
		if [ "$mode" = full ]; then
			text="$tooltip"
		else
			text="$DEV_NAME $bt"
		fi
		text="${text//\\/\\\\}"; text="${text//\"/\\\"}"
		tooltip="${tooltip//\\/\\\\}"; tooltip="${tooltip//\"/\\\"}"
		json=$(printf '{"text":"%s","tooltip":"%s","class":"%s"}' "$text" "$tooltip" "$cls")
	fi

	# Leader's own bar:
	printf '%s\n' "$json"
	# Followers (atomic write so they never see a half line):
	printf '%s\n' "$json" >"$CACHE.tmp.$$" && mv "$CACHE.tmp.$$" "$CACHE"
}

# Drain dbus-monitor's startup burst (incl. its own NameAcquired line), then
# initial state + first paint.
while coproc_alive && IFS= read -r -t 1 l <&"${BCC[0]}" 2>/dev/null; do :; done
for _ in 1 2 3 4 5; do
	coproc_alive || exit 0
	refresh_state
	[ -n "$POWERED" ] && break
	sleep 0.4
done
coproc_alive || exit 0
render

# Follow BlueZ D-Bus signals; re-query only on change (debounced). The match
# filter already restricted the stream to org.bluez, so any line here is a BlueZ
# signal — drain its remaining lines + collapse a burst, then re-query ground
# truth and repaint. The 1s-timed read + TRIGGER flag mean a USR1 (view toggle)
# can interrupt the read WITHOUT exiting the loop, and we also poll the view
# file as a fallback in case the signal is lost. If the coproc ever dies, exit
# cleanly (waybar respawns).
last_view="$(get_view_mode)"
while coproc_alive; do
	if IFS= read -r -t 1 line <&"${BCC[0]}" 2>/dev/null; then
		drain_bt "$DEBOUNCE" >/dev/null
		coproc_alive || exit 0
		refresh_state
		coproc_alive || exit 0
		render
	fi
	# Poll the BT audio profile for A2DP<->HSP/HFP flips. These are PipeWire-level
	# changes (our F9 call-prep toggle, or WirePlumber's automatic mic-drop -> A2DP
	# revert) and emit NO BlueZ signal, so the event handler above can't see them.
	# Only poll while a device is connected (keeps idle cost ~0 otherwise).
	if [ "$POWERED" = yes ] && [ "$DEV_COUNT" -gt 0 ]; then
		oa_prev="$ONAIR"
		refresh_onair
		[ "$ONAIR" != "$oa_prev" ] && render
	fi
	# View toggled (USR1) or view file changed out-of-band -> re-render.
	v="$(get_view_mode)"
	if ((TRIGGER)) || [ "$v" != "$last_view" ]; then
		TRIGGER=0
		last_view="$v"
		render
	fi
done
exit 0
