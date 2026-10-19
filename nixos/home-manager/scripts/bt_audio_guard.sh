#!/usr/bin/env bash
# bt_audio_guard — auto-heal the "connected but profile=off" zombie state.
#
# Background watcher (systemd user service). When a Bluetooth audio
# transport dies mid-switch (typically WirePlumber's post-call restore to
# A2DP — see 2026-10-19 12:18:46), WirePlumber parks the card at profile
# 'off' and nothing brings it back: connected headset, zero sinks, waybar
# shows the yellow "⚠ audio off" warning until someone runs a manual
# recovery. A connected headset without an audio sink is useless — heal it.
#
# Behavior:
#   - poll every POLL_SECS; if the headset is connected AND the BT card
#     sits at profile 'off' for DEBOUNCE_SECS, and no call-prep action is
#     running, run rofi_call_prep.sh music.
#   - transient 'off' states from our own R3/R4a cycles last < 2 s and are
#     covered by the debounce; R4a's disconnect window has NO card at all
#     (a different state, not 'off').
#   - minimum COOLDOWN_SECS between recovery attempts to avoid reconnect
#     loops against a dead link.
# All actions are logged to call-prep.log as "guard" entries.

set -u

PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"
export PATH

POLL_SECS=10
DEBOUNCE_SECS=30
COOLDOWN_SECS=90
LOG_FILE="$HOME/.local/state/call-prep.log"
PREP="$HOME/.local/bin/rofi_call_prep.sh"

log() { printf '%s  guard      %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"; }

bt_state() {
	# prints "<profile>|<mac>" for the first bluez card, or "" if no card
	LC_ALL=C pactl list cards 2>/dev/null |
		awk '/^Card #/{m=0} $1 == "Name:" && $2 ~ /^bluez_card\./ {
			m = 1; mac = $2; sub(/^bluez_card\./, "", mac); gsub(/_/, ":", mac)
		} m && $1 == "Active" && $2 == "Profile:" { print $3 "|" mac; exit }'
}

is_connected() {
	bluetoothctl info "$1" 2>/dev/null | grep -q 'Connected: yes'
}

notify_user() {
	command -v notify-send >/dev/null 2>&1 &&
		notify-send -u normal "Headset audio guard" "$1" 2>/dev/null || true
}

off_since=0
last_attempt=0

log "watcher started (poll=${POLL_SECS}s debounce=${DEBOUNCE_SECS}s cooldown=${COOLDOWN_SECS}s)"

while :; do
	sleep "$POLL_SECS"
	state="$(bt_state)"
	[ -n "$state" ] || { off_since=0; continue; }
	profile="${state%%|*}"
	mac="${state##*|}"

	if [ "$profile" = "off" ] && is_connected "$mac"; then
		now=$(date +%s)
		[ "$off_since" = 0 ] && off_since=$now
		elapsed=$((now - off_since))
		if [ "$elapsed" -lt "$DEBOUNCE_SECS" ]; then
			continue
		fi
		# our own tooling owns the card right now
		pgrep -f 'rofi_call_prep\.sh' >/dev/null 2>&1 && continue
		# cooldown between attempts
		[ $((now - last_attempt)) -lt "$COOLDOWN_SECS" ] && continue
		last_attempt=$now
		log "connected+off for ${elapsed}s — auto-recovering to music"
		notify_user "Headset was parked at 'off' — restoring audio…"
		"$PREP" music >/dev/null 2>&1 || log "recovery attempt exited non-zero"
		off_since=0
	else
		off_since=0
	fi
done
