#!/usr/bin/env bash
# rofi_call_prep.sh — Bluetooth headset prep + mid-call recovery for browser calls
#
# One rofi menu covering:
#   • Prep for call      — force HSP/HFP BEFORE joining (avoids the A2DP→HFP switch
#                          lag on the first call of the day)
#   • Back to music      — force A2DP (on-demand; autoswitch still does this alone)
#   • Recover R1/R2/R3   — mid-call recovery strategies, individually selectable so
#                          you can try them one-by-one during a lagged call and learn
#                          which lever actually fixes it
#   • Show audio state   — live diagnostics (profile, sink/source, streams, latency)
#
# The Bluetooth card / sink / source are detected at RUNTIME — nothing is hardcoded,
# so any headset works. If multiple BT audio devices are connected, the first one is
# used (refine later if needed).
#
# Usage:
#   rofi_call_prep.sh             # show the menu
#   rofi_call_prep.sh prep        # skip menu (for a future hotkey binding)
#   rofi_call_prep.sh music|r1|r2|r3|status
#
# Every action is appended to $XDG_STATE_HOME/call-prep.log (default
# ~/.local/state/call-prep.log) for post-call debugging.
#
# NOTE: all pactl parsing uses LC_ALL=C because pactl output is localized (e.g.
# German "Aktives Profil") and would otherwise break label matching.

set -u

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/call-prep.log"
mkdir -p "$(dirname "$LOG")"

# QUIET=1 suppresses success notifications — used by the F9 toggle hotkey, where
# the waybar widget already gives visual feedback (red/blue). Failures still
# surface via notify_force(), which ignores QUIET so you always learn if a
# switch actually failed.
QUIET=0
notify()       { [ "$QUIET" = 1 ] && return 0; notify-send -u normal -t 5000 "🎧 Call Prep" "$1"; }
notify_force() { notify-send -u normal -t 5000 "🎧 Call Prep" "$1"; }

# ---- runtime detection (no hardcoded device) -------------------------------

bt_card() {
	# First connected Bluetooth card (bluez_card.<mac>).
	LC_ALL=C pactl list cards short 2>/dev/null | awk '$2 ~ /^bluez_card/ {print $2; exit}'
}

active_profile() {
	# Active profile of a card, parsed locale-independently.
	LC_ALL=C pactl list cards 2>/dev/null | awk -v c="$1" '
		/^Card #/ { m = 0 }
		$1 == "Name:" && $2 == c { m = 1 }
		m && $1 == "Active" && $2 == "Profile:" { print $3; exit }
	'
}

bt_sink() {
	# First bluez playback sink.
	LC_ALL=C pactl list sinks short 2>/dev/null | awk '$2 ~ /^bluez_output/ {print $2; exit}'
}

bt_source() {
	# First bluez mic source (empty when in A2DP/off — no mic).
	LC_ALL=C pactl list sources short 2>/dev/null | awk '$2 ~ /^bluez_input/ {print $2; exit}'
}

park_sink() {
	# First non-Bluetooth sink — used as a silent parking spot for R2.
	LC_ALL=C pactl list sinks short 2>/dev/null | awk '$2 !~ /^bluez_/ {print $2; exit}'
}

sink_inputs_on() {
	# IDs of sink-inputs currently routed to the given sink.
	LC_ALL=C pactl list sink-inputs 2>/dev/null | awk -v want="$1" '
		/^Sink Input #/ { id = $3; sub(/#/, "", id); sn = "" }
		$1 == "Sink:" { sn = $2 }
		id != "" && sn == want { print id; id = "" }
	'
}

sink_latency_of() {
	# Sink latency (usec) of a sink-input id, or "n/a".
	LC_ALL=C pactl list sink-inputs 2>/dev/null | awk -v i="$1" '
		/^Sink Input #/ { m = ($3 == "#" i) }
		m && $1 == "Sink" && $2 == "Latency:" { print $3; exit }
	'
}

sink_mute_of() {
	# Mute state (0/1) of a sink name.
	LC_ALL=C pactl list sinks 2>/dev/null | awk -v p="$1" '
		/^Sink #/ { m = 0 }
		$1 == "Name:" && $2 == p { m = 1 }
		m && $1 == "Mute:" { print $2; exit }
	'
}

# Set a profile, trying primary then fallback; verify by active-profile prefix.
# Usage: set_profile <card> <want_prefix> <primary> [fallback]
set_profile() {
	local card="$1" prefix="$2" primary="$3" fallback="${4:-}"
	local prof t0 t1
	BT_SWITCH_SECS=""
	for prof in "$primary" "$fallback"; do
		[ -z "$prof" ] && continue
		t0=$(date +%s.%N)
		pactl set-card-profile "$card" "$prof" 2>/dev/null || true
		t1=$(date +%s.%N)
		BT_SWITCH_SECS=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b - a}')
		sleep 0.5
		case "$(active_profile "$card")" in
			"$prefix"*) return 0 ;;
		esac
	done
	return 1
}

log() {
	# Append: timestamp  action  pre=..  post=..  bt_switch=Xs  settle=Ys  streams=N  lat=..
	local action="$1" pre="$2" post="$3"
	local card sink n id lat bts stl
	card="$(bt_card)"
	sink="$(bt_sink)"
	n=0
	lat="n/a"
	if [ -n "$sink" ]; then
		n="$(sink_inputs_on "$sink" | wc -l | tr -d ' ')"
		id="$(sink_inputs_on "$sink" | head -1)"
		[ -n "$id" ] && lat="$(sink_latency_of "$id") us"
	fi
	bts="${BT_SWITCH_SECS:-n/a}"; [ "$bts" != "n/a" ] && bts="${bts}s"
	stl="${SETTLE_SECS:-n/a}"; [ "$stl" != "n/a" ] && stl="${stl}s"
	printf '%s  %-10s pre=%-22s post=%-22s bt_switch=%-6s settle=%-6s streams=%s lat=%s\n' \
		"$(date '+%F %T')" "$action" "${pre:-none}" "${post:-none}" "$bts" "$stl" "$n" "$lat" >> "$LOG"
}

# ---- actions ---------------------------------------------------------------

do_prep() {
	local card pre post msg
	card="$(bt_card)"
	if [ -z "$card" ]; then
		notify "$(printf '⚠️ No Bluetooth headset connected.\nConnect one first (rofi_bluetooth.sh).')"
		log prep none none
		return 1
	fi
	pre="$(active_profile "$card")"
	case "$pre" in
		headset-head-unit*)
			notify "$(printf '✅ Already call-ready (%s).\nSafe to join the call now.' "$pre")"
			log prep "$pre" "$pre"
			return 0
			;;
	esac
	if set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd"; then
		sleep 0.5 # let the Bluetooth transport settle before the browser opens streams
		SETTLE_SECS=0.5
		post="$(active_profile "$card")"
		if [ -n "$(bt_source)" ]; then
			msg="$(printf '✅ Call-ready: %s, mic available.\nJoin the call now.' "$post")"
		else
			msg="$(printf '⚠️ Profile %s set, but mic source is missing.\nCheck the device.' "$post")"
		fi
		notify "$msg"
		log prep "$pre" "$post"
	else
		notify "$(printf '⚠️ Could not switch to a headset profile.\n(card: %s)' "$card")"
		log prep "$pre" "$(active_profile "$card")"
		return 1
	fi
}

do_music() {
	local card pre post
	card="$(bt_card)"
	if [ -z "$card" ]; then
		notify "⚠️ No Bluetooth headset connected."
		log music none none
		return 1
	fi
	pre="$(active_profile "$card")"
	if set_profile "$card" "a2dp-sink" "a2dp-sink" "a2dp-sink-sbc"; then
		post="$(active_profile "$card")"
		SETTLE_SECS=0
		notify "🎵 Back to music: $post"
		log music "$pre" "$post"
	else
		notify "$(printf '⚠️ Could not switch to A2DP.\n(card: %s)' "$card")"
		log music "$pre" "$(active_profile "$card")"
		return 1
	fi
}

do_toggle() {
	# Flip between call (HSP/HFP) and music (A2DP) based on the current profile.
	local card pre post
	card="$(bt_card)"
	if [ -z "$card" ]; then
		notify_force "⚠️ No Bluetooth headset connected."
		log toggle none none
		return 1
	fi
	pre="$(active_profile "$card")"
	case "$pre" in
		headset-head-unit*)
			# currently call mode -> music
			if set_profile "$card" "a2dp-sink" "a2dp-sink" "a2dp-sink-sbc"; then
				post="$(active_profile "$card")"
				SETTLE_SECS=0
			notify "🎵 Music mode: $post"
				log toggle "$pre" "$post"
			else
				notify_force "⚠️ Could not switch to A2DP."
				log toggle "$pre" "$(active_profile "$card")"
			fi
			;;
		*)
			# currently music / off / unknown -> call mode
			if set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd"; then
				sleep 0.5 # let the Bluetooth transport settle before joining
				SETTLE_SECS=0.5
				post="$(active_profile "$card")"
				notify "$(printf '📞 Call mode: %s — join now.' "$post")"
				log toggle "$pre" "$post"
			else
				notify_force "⚠️ Could not switch to headset profile."
				log toggle "$pre" "$(active_profile "$card")"
			fi
			;;
	esac
}

do_r1() {
	# Gentle: suspend/resume the bluez sink + source (flushes device buffers).
	local card pre sink src
	card="$(bt_card)"
	pre="$(active_profile "${card:-none}")"
	sink="$(bt_sink)"
	if [ -z "$sink" ]; then
		notify "⚠️ No Bluetooth sink found."
		log R1 "$pre" "$pre"
		return 1
	fi
	pactl suspend-sink "$sink" 1 2>/dev/null || true
	pactl suspend-sink "$sink" 0 2>/dev/null || true
	src="$(bt_source)"
	if [ -n "$src" ]; then
		pactl suspend-source "$src" 1 2>/dev/null || true
		pactl suspend-source "$src" 0 2>/dev/null || true
	fi
	sleep 0.5
	notify "$(printf '🎧 R1 applied (suspend/resume).\nIf still lagged, try R2.')"
	log R1 "$pre" "$(active_profile "${card:-none}")"
}

do_r2() {
	# Medium: move the browser playback stream(s) to a muted non-BT sink and back,
	# forcing a relink of the playback stream (closest to "rejoin" for that path).
	local card pre sink park ids was_mute id
	card="$(bt_card)"
	pre="$(active_profile "${card:-none}")"
	sink="$(bt_sink)"
	if [ -z "$sink" ]; then
		notify "⚠️ No Bluetooth sink found."
		log R2 "$pre" "$pre"
		return 1
	fi
	park="$(park_sink)"
	if [ -z "$park" ]; then
		notify "⚠️ No non-BT sink available to park the stream.\nSkipping R2."
		log R2 "$pre" "$pre"
		return 1
	fi
	ids="$(sink_inputs_on "$sink")"
	if [ -z "$ids" ]; then
		notify "$(printf '🎧 R2: no playback stream on the BT sink.\n(Audio may be routed elsewhere.)')"
		log R2 "$pre" "$(active_profile "${card:-none}")"
		return 1
	fi
	# Mute the parking sink so nothing leaks to the laptop speakers.
	was_mute="$(sink_mute_of "$park")"
	was_mute="${was_mute:-0}"
	pactl set-sink-mute "$park" 1 2>/dev/null || true
	for id in $ids; do
		pactl move-sink-input "$id" "$park" 2>/dev/null || true
	done
	sleep 0.3
	# Move whatever is now on the parking sink back to the BT sink (best effort).
	for id in $(sink_inputs_on "$park"); do
		pactl move-sink-input "$id" "$sink" 2>/dev/null || true
	done
	pactl set-sink-mute "$park" "$was_mute" 2>/dev/null || true
	sleep 0.3
	notify "$(printf '🎧 R2 applied (stream moved out & back).\nIf still lagged, try R3.')"
	log R2 "$pre" "$(active_profile "${card:-none}")"
}

do_r3() {
	# Aggressive: cycle the profile off → headset (mimics the "2nd call" warm state).
	local card pre post
	card="$(bt_card)"
	if [ -z "$card" ]; then
		notify "⚠️ No Bluetooth card."
		log R3 none none
		return 1
	fi
	pre="$(active_profile "$card")"
	pactl set-card-profile "$card" off 2>/dev/null || true
	sleep 1
	set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd" || true
	sleep 1
	post="$(active_profile "$card")"
	notify "$(printf '🎧 R3 applied (profile cycle off→HFP).\nIf still lagged, rejoin the call.')"
	log R3 "$pre" "$post"
}

do_status() {
	local card prof sink src n id lat msg
	card="$(bt_card)"
	prof="(no bt card)"
	[ -n "$card" ] && prof="$(active_profile "$card")"
	sink="$(bt_sink)"
	src="$(bt_source)"
	n=0
	lat="n/a"
	if [ -n "$sink" ]; then
		n="$(sink_inputs_on "$sink" | wc -l | tr -d ' ')"
		id="$(sink_inputs_on "$sink" | head -1)"
		[ -n "$id" ] && lat="$(sink_latency_of "$id") us"
	fi
	msg="$(printf 'Card:   %s\nProfile: %s\nSink:   %s\nMic:    %s\nStreams on BT sink: %s\nSink latency: %s' \
		"${card:-(none)}" "$prof" "${sink:-(none)}" "${src:-(none)}" "$n" "$lat")"
	notify "$msg"
	printf '%s  STATUS  profile=%s streams=%s lat=%s\n' "$(date '+%F %T')" "$prof" "$n" "$lat" >> "$LOG"
	printf '%s\n' "$msg"
}

# ---- dispatch --------------------------------------------------------------

case "${1:-}" in
	prep) do_prep; exit ;;
	music) do_music; exit ;;
	toggle) QUIET=1; do_toggle; exit ;;
	r1) do_r1; exit ;;
	r2) do_r2; exit ;;
	r3) do_r3; exit ;;
	status) do_status; exit ;;
esac

items=(
	"📞  Prep for call (force HSP/HFP)"
	"🎵  Back to music (force A2DP)"
	"🎧  Recover R1 · suspend/resume (gentle)"
	"🎧  Recover R2 · move stream out & back"
	"🎧  Recover R3 · profile cycle off→HFP (aggressive)"
	"📊  Show audio state (debug)"
)

sel="$(printf '%s\n' "${items[@]}" | rofi -dmenu -i -no-custom -p "🎧 Call Prep")"

case "$sel" in
	*"Prep for call"*) do_prep ;;
	*"Back to music"*) do_music ;;
	*"R1"*) do_r1 ;;
	*"R2"*) do_r2 ;;
	*"R3"*) do_r3 ;;
	*"Show audio state"*) do_status ;;
	"") exit 0 ;;
esac
