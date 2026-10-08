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
#   • AUTO · triage-first — read-only checks classify the CURRENT failure mode
#                          (stack hang / no card / transport collapse / misrouting /
#                          classic stale loopback), show the verdict, run the matching
#                          fix. Start here when audio breaks mid-call.
#   • R4 ladder          — link-layer live fixes, NO headset buttons needed:
#                          R4a PC-side reconnect · R4b adapter power-cycle ·
#                          R4c PipeWire stack restart.
#   • Gather diagnostics — writes a ready-to-paste analysis prompt (live audio state
#                          + full background context) to /tmp/call-audio-diag.md and
#                          the clipboard, so a fresh session can diagnose with no
#                          prior history. Run it the moment a call lags, BEFORE R3.
#   • Show audio state   — live diagnostics (profile, sink/source, streams, latency)
#
# The Bluetooth card / sink / source are detected at RUNTIME — nothing is hardcoded,
# so any headset works. If multiple BT audio devices are connected, the first one is
# used (refine later if needed).
#
# Usage:
#   rofi_call_prep.sh             # show the menu
#   rofi_call_prep.sh prep        # skip menu (for a future hotkey binding)
#   rofi_call_prep.sh auto|r4|r4b|r4c|music|r1|r2|r3|status|diag
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
	# IDs of sink-inputs currently routed to the given sink. NOTE: pactl lists
	# the target as a sink INDEX ("Sink: 75126"), not a name — comparing by
	# name only made this return 0 for every stream (2026-10-07: triage then
	# misfired as MISROUTED and AUTO ran a no-op R2 instead of R3). Match both.
	local idx
	idx="$(LC_ALL=C pactl list sinks short 2>/dev/null | awk -v w="$1" '$2 == w {print $1; exit}')"
	LC_ALL=C pactl list sink-inputs 2>/dev/null | awk -v want="$1" -v idx="$idx" '
		/^Sink Input #/ { id = $3; sub(/#/, "", id); sn = "" }
		$1 == "Sink:" { sn = $2 }
		id != "" && (sn == want || (idx != "" && sn == idx)) { print id; id = ""; sn = "" }
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

# Full off → headset cycle (R3 mechanics) with the autoswitch guard, shared by
# prep / F9-toggle (call direction) / R3. Reason: in-place A2DP→HFP switches
# leave the loopback capture graph stale — the constant 1-3s mic-delay bug —
# and only a full off→on cycle recreates transport, sink and loopback source.
# The guard (2026-08-26 incident): with a live capture stream, WirePlumber's
# bluetooth autoswitch fires during the 'off' phase and records 'off' as the
# profile to restore at call end — afterwards the card comes up DEAD (no sink,
# audio on the laptop speakers, waybar shows normal blue). Disabling autoswitch
# around the cycle means only OUR explicit switches happen. Returns set_profile's rc.
cycle_to_headset() {
	local card="$1" as_prev rc
	as_prev="$(wpctl settings bluetooth.autoswitch-to-headset-profile 2>/dev/null |
		awk -F': ' '$1 == "Value" { print $2; exit }')"
	wpctl settings bluetooth.autoswitch-to-headset-profile false 2>/dev/null || true
	pactl set-card-profile "$card" off 2>/dev/null || true
	sleep 1
	set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd"
	rc=$?
	wpctl settings bluetooth.autoswitch-to-headset-profile "${as_prev:-true}" 2>/dev/null || true
	return "$rc"
}

# ---- link-layer triage helpers (AUTO / R4) ---------------------------------

bt_mac() {
	# Device address of the first BT audio card; falls back to any connected,
	# then any paired device (card can be absent in NO-CARD situations).
	local c mac
	c="$(bt_card)"
	if [ -n "$c" ]; then
		echo "$c" | sed 's/^bluez_card\.//; s/_/:/g'
		return 0
	fi
	mac="$(bluetoothctl devices Connected 2>/dev/null | awk 'NR==1 {print $2}')"
	[ -z "$mac" ] && mac="$(bluetoothctl devices Paired 2>/dev/null | awk 'NR==1 {print $2}')"
	echo "$mac"
}

transport_failures() {
	# Count "Failure in Bluetooth audio transport" lines in the wireplumber
	# journal of the last N minutes (default 3) — the H4 collapse signal.
	journalctl --user -u wireplumber --since "-${1:-3} min" --no-pager 2>/dev/null |
		grep -c 'Failure in Bluetooth audio transport'
}

pulse_alive() {
	# Is the PipeWire/pulse server answering at all? (R4c signal: hung stack)
	timeout 3 pactl info >/dev/null 2>&1
}

triage() {
	# Read-only classification of the CURRENT failure mode. Sets TRIAGE_MODE /
	# TRIAGE_LABEL / TRIAGE_PLAN globals for do_auto(). Order matters: link and
	# stack problems first — pressing R3 into a collapsing link removes the last
	# working sink (2026-09-28 incident: settle=n/a, total silence).
	local card sink si_n bt_n so_n fails
	TRIAGE_MODE="HEALTHY"
	TRIAGE_LABEL="nothing obviously broken"
	TRIAGE_PLAN="none"
	if ! pulse_alive; then
		TRIAGE_MODE="STACK-HUNG"
		TRIAGE_LABEL="PipeWire/pulse server not answering"
		TRIAGE_PLAN="R4c"
		return 0
	fi
	card="$(bt_card)"
	if [ -z "$card" ]; then
		TRIAGE_MODE="NO-CARD"
		TRIAGE_LABEL="no Bluetooth audio card (device gone or not exported)"
		TRIAGE_PLAN="R4a"
		return 0
	fi
	fails="$(transport_failures 3)"
	if [ "${fails:-0}" -ge 2 ]; then
		TRIAGE_MODE="TRANSPORT-COLLAPSE"
		TRIAGE_LABEL="${fails} BT transport failures in 3 min — the link is dying"
		TRIAGE_PLAN="R4a"
		return 0
	fi
	sink="$(bt_sink)"
	si_n="$(LC_ALL=C pactl list sink-inputs short 2>/dev/null | wc -l | tr -d ' ')"
	bt_n=0
	[ -n "$sink" ] && bt_n="$(sink_inputs_on "$sink" | wc -l | tr -d ' ')"
	so_n="$(LC_ALL=C pactl list source-outputs short 2>/dev/null | wc -l | tr -d ' ')"
	if [ "$si_n" -gt 0 ] && [ -n "$sink" ] && [ "$bt_n" -eq 0 ]; then
		TRIAGE_MODE="MISROUTED"
		TRIAGE_LABEL="playback streams exist but none on the BT sink"
		TRIAGE_PLAN="R2"
		return 0
	fi
	if [ "$si_n" -gt 0 ] || [ "$so_n" -gt 0 ]; then
		TRIAGE_MODE="STALE-LOOPBACK?"
		TRIAGE_LABEL="streams active, link stable — classic mic-delay pattern"
		TRIAGE_PLAN="R3"
	else
		TRIAGE_MODE="HEALTHY"
		TRIAGE_LABEL="no active streams, no failures"
		TRIAGE_PLAN="none"
	fi
}

# Compact tag of the current default sink (bt / alsa / hdmi / other / none) —
# makes H1 (playback pinned to the wrong sink) visible in the action log.
def_sink_tag() {
	local tag
	tag="$(LC_ALL=C pactl info 2>/dev/null | awk -F': ' '
		$1 == "Default Sink" {
			if ($2 ~ /^bluez_output/) print "bt"
			else if ($2 ~ /hdmi/) print "hdmi"
			else if ($2 ~ /^alsa_output/) print "alsa"
			else print "other"
			exit
		}')"
	echo "${tag:-none}"
}

log() {
	# Append: timestamp  action  pre=..  post=..  bt_switch=Xs  settle=Ys  streams=N  lat=..
	#              mode= cycle|cycle-fb|inplace   def_sink= default-sink tag (H1 signal)
	local action="$1" pre="$2" post="$3"
	local card sink n id lat bts stl ds
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
	ds="$(def_sink_tag)"
	printf '%s  %-10s pre=%-22s post=%-22s bt_switch=%-6s settle=%-6s streams=%s lat=%s mode=%s def_sink=%s\n' \
		"$(date '+%F %T')" "$action" "${pre:-none}" "${post:-none}" "$bts" "$stl" "$n" "$lat" "${ACTION_MODE:-n/a}" "$ds" >> "$LOG"
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
	# Standard since 2026-08-26: enter call mode via the full off→HFP cycle —
	# in-place A2DP→HFP switches are the identified mic-delay trigger. Keep the
	# in-place switch only as a fallback if the cycle cannot complete.
	if cycle_to_headset "$card"; then
		ACTION_MODE="cycle"
	elif set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd"; then
		ACTION_MODE="cycle-fb"
	else
		ACTION_MODE="fail"
		notify "$(printf '⚠️ Could not switch to a headset profile.\n(card: %s)' "$card")"
		log prep "$pre" "$(active_profile "$card")"
		return 1
	fi
	sleep 0.5 # let the Bluetooth transport settle before the browser opens streams
	SETTLE_SECS=0.5
	post="$(active_profile "$card")"
	if [ -n "$(bt_source)" ]; then
		msg="$(printf '✅ Call-ready: %s (via %s), mic available.\nJoin the call now.' "$post" "$ACTION_MODE")"
	else
		msg="$(printf '⚠️ Profile %s set, but mic source is missing.\nCheck the device.' "$post")"
	fi
	notify "$msg"
	log prep "$pre" "$post"
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
	ACTION_MODE=inplace
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
			ACTION_MODE=inplace
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
			# currently music / off / unknown -> call mode.
			# Full off→HFP cycle since 2026-08-26 (in-place = delay trigger);
			# in-place only as a fallback.
			if cycle_to_headset "$card"; then
				ACTION_MODE="cycle"
			elif set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd"; then
				ACTION_MODE="cycle-fb"
			else
				ACTION_MODE="fail"
				notify_force "⚠️ Could not switch to headset profile."
				log toggle "$pre" "$(active_profile "$card")"
				return 1
			fi
			sleep 0.5 # let the Bluetooth transport settle before joining
			SETTLE_SECS=0.5
			post="$(active_profile "$card")"
			notify "$(printf '📞 Call mode: %s (via %s) — join now.' "$post" "$ACTION_MODE")"
			log toggle "$pre" "$post"
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
	# Aggressive mid-call recovery: full off → headset cycle via
	# cycle_to_headset (includes the autoswitch guard — see its comment for the
	# 2026-08-26 poisoning incident). Recreates the BT transport, the
	# bluez_output sink AND the loopback source node; usually the lever that
	# actually clears the delay.
	local card pre post
	card="$(bt_card)"
	if [ -z "$card" ]; then
		notify "⚠️ No Bluetooth card."
		log R3 none none
		return 1
	fi
	pre="$(active_profile "$card")"
	cycle_to_headset "$card" || true
	ACTION_MODE=cycle
	sleep 1
	post="$(active_profile "$card")"
	notify "$(printf '🎧 R3 applied (profile cycle off→HFP).\nIf still lagged, rejoin the call.')"
	log R3 "$pre" "$post"
}

r4_bringup() {
	# Shared tail of R4a/R4b/R4c: wait for the card, ensure the call profile
	# (guarded off→HFP cycle unless autoswitch already did it), wait for the
	# sink, then re-pin the remembered playback streams and restore the default
	# sink. Arg 1: space-separated sink-input ids. rc 0 = sink usable.
	local ids="$1" card sink id i
	i=0
	while [ "$i" -lt 12 ] && [ -z "$(bt_card)" ]; do
		sleep 1
		i=$((i + 1))
	done
	SETTLE_SECS="$i"
	card="$(bt_card)"
	[ -z "$card" ] && return 1
	case "$(active_profile "$card")" in
		headset-head-unit*) ;; # autoswitch got there first
		*)
			cycle_to_headset "$card" ||
				set_profile "$card" "headset-head-unit" "headset-head-unit" "headset-head-unit-cvsd" ||
				true
			;;
	esac
	i=0
	while [ "$i" -lt 6 ] && [ -z "$(bt_sink)" ]; do
		sleep 1
		i=$((i + 1))
	done
	sink="$(bt_sink)"
	if [ -n "$sink" ]; then
		pactl set-default-sink "$sink" 2>/dev/null || true
		for id in $ids; do
			pactl move-sink-input "$id" "$sink" 2>/dev/null || true
		done
	fi
	[ -n "$sink" ]
}

do_r4a() {
	# R4a — PC-side headset reconnect (2026-09-28): the live fix for H4
	# transport collapse and a missing card. bluetoothctl disconnect/connect
	# needs NO headset buttons (no 30s long-press dance); the browser call
	# survives, expect a ~10-15s audio gap. Proven 2026-09-09.
	local mac pre ids n
	mac="$(bt_mac)"
	if [ -z "$mac" ]; then
		notify_force "⚠️ R4: no Bluetooth device address found."
		log R4 none none
		return 1
	fi
	pre="$(active_profile "$(bt_card)")"
	notify_force "$(printf '🔌 R4a: reconnecting headset %s…\n~10-15s audio gap — the call itself survives.' "$mac")"
	# remember ALL playback streams so they can be re-pinned afterwards
	ids="$(LC_ALL=C pactl list sink-inputs short 2>/dev/null | awk '{print $1}')"
	timeout 10 bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
	sleep 2
	timeout 15 bluetoothctl connect "$mac" >/dev/null 2>&1 || true
	if ! r4_bringup "$ids"; then
		notify_force "⚠️ R4a: card/sink did not come back.\nNext: R4b (adapter power cycle) or rejoin."
		ACTION_MODE=r4a
		log R4 "${pre:-none}" "$(active_profile "$(bt_card)")"
		return 1
	fi
	n="$(printf '%s\n' "$ids" | wc -w | tr -d ' ')"
	ACTION_MODE=r4a
	notify "$(printf '🎧 R4a done: %s (%s stream(s) re-pinned).' "$(active_profile "$(bt_card)")" "$n")"
	log R4 "${pre:-none}" "$(active_profile "$(bt_card)")"
	return 0
}

do_r4b() {
	# R4b — adapter power cycle (R4a escalation when the card won't come back,
	# e.g. after an hci0 firmware wedge à la 2026-09-09).
	local mac pre ids n
	mac="$(bt_mac)"
	if [ -z "$mac" ]; then
		notify_force "⚠️ R4b: no Bluetooth device address found."
		log R4b none none
		return 1
	fi
	pre="$(active_profile "$(bt_card)")"
	notify_force "🔄 R4b: power-cycling the BT adapter (~20-25s)…"
	ids="$(LC_ALL=C pactl list sink-inputs short 2>/dev/null | awk '{print $1}')"
	bluetoothctl power off >/dev/null 2>&1 || true
	sleep 1
	bluetoothctl power on >/dev/null 2>&1 || true
	sleep 3
	timeout 15 bluetoothctl connect "$mac" >/dev/null 2>&1 || true
	if ! r4_bringup "$ids"; then
		notify_force "⚠️ R4b: still no card.\nNext: R4c (stack restart) or rejoin the call."
		ACTION_MODE=r4b
		log R4b "${pre:-none}" "$(active_profile "$(bt_card)")"
		return 1
	fi
	n="$(printf '%s\n' "$ids" | wc -w | tr -d ' ')"
	ACTION_MODE=r4b
	notify "$(printf '🎧 R4b done: %s (%s stream(s) re-pinned).' "$(active_profile "$(bt_card)")" "$n")"
	log R4b "${pre:-none}" "$(active_profile "$(bt_card)")"
	return 0
}

do_r4c() {
	# R4c — audio-stack restart (pactl unresponsive; the 2026-09-09 wedged
	# stack). Restart pipewire/wireplumber, then run the R4a reconnect tail.
	local pre
	pre="$(active_profile "$(bt_card)")"
	notify_force "♻️ R4c: restarting PipeWire stack (~30s)…"
	systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null || true
	sleep 4
	do_r4a
	ACTION_MODE=r4c
	log R4c "${pre:-none}" "$(active_profile "$(bt_card)")"
}

do_auto() {
	# Triage-first rescue: classify read-only, TELL the user the verdict (the
	# visibility the R1-R3 menu lacked), then run the matching fix. R3 is only
	# chosen when the link is provably stable — pressing it into a collapsing
	# transport removes the last working sink (2026-09-28 incident).
	local pre
	triage
	notify_force "$(printf '🔍 AUTO verdict: %s\n%s\n→ plan: %s' "$TRIAGE_MODE" "$TRIAGE_LABEL" "$TRIAGE_PLAN")"
	pre="$(active_profile "$(bt_card)")"
	case "$TRIAGE_PLAN" in
		R4c) do_r4c ;;
		R4a)
			do_r4a || do_r4b
			;;
		R2) do_r2 ;;
		R3) do_r3 ;;
		*)
			notify "✅ AUTO: nothing to fix."
			ACTION_MODE="auto-none"
			log AUTO "${pre:-none}" "$(active_profile "$(bt_card)")"
			return 0
			;;
	esac
	ACTION_MODE="auto-${TRIAGE_MODE}"
	log AUTO "${pre:-none}" "$(active_profile "$(bt_card)")"
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

# ---- diagnostics -----------------------------------------------------------

# Resolve a wpctl node id from `wpctl status` by matching a substring of the
# node line. The id is always the FIRST number on a node-entry line ("81. name"),
# so we split on non-digits and take the first run. The /[0-9]\. / guard skips
# prose lines (e.g. the Settings block also prints "bluez_input.<mac>" with no id).
wp_node_id() {
	LC_ALL=C wpctl status 2>/dev/null | awk -v name="$1" '
		index($0, name) && $0 ~ /[0-9]\. / {
			n = split($0, parts, /[^0-9]/)
			for (i = 1; i <= n; i++) if (parts[i] != "") { print parts[i]; exit }
		}
	'
}

# First device id tagged [bluez5] in wpctl status (e.g. the soundcore entry).
wp_bluez_device_id() {
	LC_ALL=C wpctl status 2>/dev/null | awk '
		index($0, "bluez5") && $0 ~ /[0-9]\. / {
			n = split($0, parts, /[^0-9]/)
			for (i = 1; i <= n; i++) if (parts[i] != "") { print parts[i]; exit }
		}
	'
}

do_diag() {
	# Write a self-contained, ready-to-paste analysis prompt to
	# /tmp/call-audio-diag.md: live audio state + full background context, so a
	# fresh LLM session can diagnose the recurring call-audio-delay WITHOUT any
	# prior history. Also copies to the clipboard (wl-copy/xclip/xsel, best
	# effort) and logs a GATHER marker. Run this the moment a call lags, BEFORE
	# pressing R3, so we capture the actual broken state.
	local out now card prof sink src si_n so_n bluez_in_id cap_id dev_id clip clipmsg
	out="/tmp/call-audio-diag.md"
	now="$(date '+%F %T %Z')"
	card="$(bt_card)"
	prof="(no bt card)"; [ -n "$card" ] && prof="$(active_profile "$card")"
	sink="$(bt_sink)"
	src="$(bt_source)"
	si_n="$(LC_ALL=C pactl list sink-inputs short 2>/dev/null | wc -l | tr -d ' ')"
	so_n="$(LC_ALL=C pactl list source-outputs short 2>/dev/null | wc -l | tr -d ' ')"
	bluez_in_id="$(wp_node_id 'bluez_input.')"
	cap_id="$(wp_node_id 'bluez_capture_internal')"
	dev_id="$(wp_bluez_device_id)"
	# Driver node = the REAL HFP capture node behind the loopback source
	# (node.driver-id of the loopback node) — the one link of the chain the
	# old snapshots never showed.
	drv_id=""
	if [ -n "$bluez_in_id" ]; then
		drv_id="$(LC_ALL=C wpctl inspect "$bluez_in_id" 2>/dev/null |
			awk -F' = ' '$1 ~ /driver-id/ { gsub(/"/, "", $2); print $2; exit }')"
	fi

	{
		cat <<EOF
# Recurring call-audio delay — diagnostic snapshot (ready to paste)

Captured: ${now}

Hi — I'm hitting the audio-delay issue again during a browser call with my
Bluetooth headset. Please analyze the LIVE snapshot below and tell me the most
likely cause + which recovery to try (AUTO / R1 / R2 / R3 / R4 / rejoin). Do NOT change
anything or switch the Bluetooth profile without confirming with me first.

This file is self-contained: the "Quick read", "Hypotheses" and "Background"
sections give you everything you need with no prior session context.

## Quick read of THIS capture

- BT card:         ${card:-(none)}
- Active profile:  ${prof}
- BT sink:         ${sink:-(none  — no bluez_output sink; profile is off/A2DP)}
- BT mic source:   ${src:-(none  — profile has no mic, e.g. A2DP or off)}
- Sink-inputs (playback streams) total:  ${si_n}
- Source-outputs (capture streams) total: ${so_n}
- A stream/call appears active: $([ "$si_n" -gt 0 ] || [ "$so_n" -gt 0 ] && echo YES || echo no)

## Hypotheses to evaluate against the data

- H1 — Output misrouting / sink-input pinning. The browser (Chromium WebRTC)
  pins its playback stream to whatever the DEFAULT sink was at call-start and
  ignores later default changes. If the BT sink was briefly absent (profile
  off) at call-start, playback locked onto the laptop speakers for the whole
  call. Evidence: a sink-input whose "Sink:" is NOT bluez_output.*, and/or
  "Default Sink" (pactl info) != a bluez_output sink while a call is active.
  R2 would print "no playback stream on the BT sink".
- H2 — Loopback capture node degraded. Call apps do NOT capture the BT mic
  directly; WirePlumber exposes it through a LOOPBACK SOURCE node built by
  CreateDeviceLoopbackSource (scripts/monitors/bluez.lua). If that node (or its
  internal bridge) suspends idle and resumes degraded, you get a constant 1-3s
  mic delay until the stream is torn down. Evidence: in "wpctl inspect
  bluez_input.*" below, session.suspend-timeout-seconds should be 0; note any
  suspended/odd node state. Also inspect the bluez_capture_internal bridge.
- H3 — Card stuck at profile off after a call (fixed 2026-08-26, kept for
  history): an unguarded mid-call off->HFP cycle made WirePlumber's autoswitch
  record 'off' as the profile to restore at call end; afterwards the card had
  no sink and playback fell back to the laptop speakers. Evidence: "Active
  Profile: off" while connected. Recover: pactl set-card-profile <card> a2dp-sink,
  restart wireplumber if it flip-flops.
- H4 — Bluetooth TRANSPORT collapse (seen 2026-08-31, low/dead headset battery):
  the Bluetooth link itself dies every ~10-20s — journal shows "spa.bluez5:
  Failure in Bluetooth audio transport" + bluez nodes "running -> error" with
  new object serials each cycle (auto-recreated by WirePlumber). NOT a PipeWire
  routing/suspend problem — R1/R2/R3 operate at the wrong layer. Symptom:
  default sink flaps BT <-> internal speakers (pulsemixer flickers), call
  survives on auto-recovery. Check the journal section + headset battery
  (bluetoothctl info shows "Battery Percentage"). Fix: charge the headset /
  reconnect the device. If it recurs at high battery, test CVSD
  (headset-head-unit-cvsd) for an mSBC instability.

## Background (so this works with NO prior context)

Environment: NixOS, PipeWire + WirePlumber 0.5.x, headset = soundcore Q20i_new,
browser calls = Teams / Signal (ringrtc). The documented bug is a constant 1-3s
delay of the LOCAL mic reaching the other side (and sometimes echo / misrouted
playback) that only clears by rejoining the call.

I have a rofi helper (this script) that:
  - F9 toggle: flips the BT card profile A2DP (music) <-> headset-head-unit/HFP.
    Entering call mode uses a full off->HFP cycle (R3 mechanics, autoswitch-
    guarded) since 2026-08-26 — in-place A2DP->HFP switches were identified as
    the mic-delay trigger.
  - R1: suspend/resume the bluez sink + source (gentle; flush buffers).
  - R2: move the browser PLAYBACK stream to a muted non-BT sink and back. If no
        stream is on the BT sink it prints "no playback stream on the BT sink
        (Audio may be routed elsewhere)" — a strong H1 signal.
  - R3: set-card-profile off -> headset-head-unit (aggressive; recreates the BT
        transport, the bluez_output sink AND the loopback source node; resets
        both routing and node freshness — usually the one that actually fixes it).
        The off-phase is autoswitch-guarded: unguarded, WirePlumber's autoswitch
        recorded 'off' as the end-of-call restore target and left the card dead.
  - AUTO: triage-first rescue — read-only checks detect WHICH failure mode is
        live (stack hang / no card / transport collapse / misrouting / classic
        stale loopback), notify the verdict, then run the matching fix.
  - R4:  PC-side headset reconnect (bluetoothctl disconnect/connect — NO headset
        buttons, the browser call survives, ~10-15s audio gap) followed by HFP
        bring-up and stream re-pinning. The live fix for H4 transport collapse.
        Escalations: R4b = adapter power cycle, R4c = PipeWire stack restart.

Fixes already applied (services.pipewire.wireplumber in audio.nix):
  - 10-disable-suspend      ALSA nodes:        session.suspend-timeout-seconds = 0
  - 10-bluetooth-nosuspend  bluez_* nodes:     suspend = 0, dither.method = none
  - 11-bluetooth-codecs     bluez5.enable-msbc = true, bluez5.enable-sbc-xq = true
  - configPackages patch    bluez.lua:449 adds ["session.suspend-timeout-seconds"] = 0
                            to the CreateDeviceLoopbackSource node (the source call
                            apps capture from; NOT reachable by monitor.bluez.rules).
  - rofi_call_prep.sh       2026-08-26: cycle_to_headset() (off->HFP with autoswitch
                            guard) is the standard for prep/toggle/R3; the action log
                            gained mode= and def_sink= fields.

Relevant files (repo: ~/git/nix-setup):
  - nixos/nixos-modules/hardware/audio.nix
  - nixos/home-manager/scripts/rofi_call_prep.sh   (this script)
  - nixos/docs/hints/pipewire-bluetooth-audio.md
  - action log: ~/.local/state/call-prep.log   (recent tail below)

Known open question: toggling to headset via F9 BEFORE the call does NOT prevent
the delay, but R3 (run mid-call) fixes it. Leading theory: an in-place profile
switch leaves the loopback graph / default-sink routing stale, and only R3's full
off->on cycle recreates everything fresh WITH the call's streams already present.

## LIVE snapshot

### pactl info  (server + Default Sink / Default Source)
$(LC_ALL=C pactl info 2>/dev/null)

### BlueZ card block  (active profile, codec, available profiles, ports)
$(LC_ALL=C pactl list cards 2>/dev/null | awk '/^Card #/{m=0} $1=="Name:"&&$2 ~ /^bluez_card/{m=1} m')

### Sinks  (name / description / state / mute / volume)
$(LC_ALL=C pactl list sinks 2>/dev/null | awk '/^Sink #/{print "---"} /^Sink #|Description:|Name:|State:|Mute:|Volume: front-left/{print}')

### Sources  (name / description / state / mute)
$(LC_ALL=C pactl list sources 2>/dev/null | awk '/^Source #/{print "---"} /^Source #|Description:|Name:|State:|Mute:/{print}')

### Sink-inputs  *** PLAYBACK — what is playing, on WHICH sink, latency, app ***
$(LC_ALL=C pactl list sink-inputs 2>/dev/null | awk '/^Sink Input #/{print "---"} /^Sink Input #|Sink:|Sink Latency:|Mute:|application.name =|media.name =|application.process.binary =/{print}')

### Source-outputs  *** CAPTURE — what is recording the mic, app ***
$(LC_ALL=C pactl list source-outputs 2>/dev/null | awk '/^Source Output #/{print "---"} /^Source Output #|Source:|Mute:|application.name =|media.name =|application.process.binary =/{print}')

### wpctl status  (default sink/source marked with *; loopback filter under Filters)
$(LC_ALL=C wpctl status 2>/dev/null)

### wpctl inspect: bluez_input loopback source node  (id=${bluez_in_id:-not found})
$([ -n "$bluez_in_id" ] && LC_ALL=C wpctl inspect "$bluez_in_id" 2>/dev/null || echo "(bluez_input.* node not present — profile likely off or A2DP)")

### wpctl inspect: bluez_capture_internal bridge node  (id=${cap_id:-not found})
$([ -n "$cap_id" ] && LC_ALL=C wpctl inspect "$cap_id" 2>/dev/null || echo "(bluez_capture_internal node not present)")

### wpctl inspect: HFP capture DRIVER node  (id=${drv_id:-not found}; resolved from node.driver-id of the loopback source — the REAL BT capture node)
$([ -n "$drv_id" ] && LC_ALL=C wpctl inspect "$drv_id" 2>/dev/null || echo "(driver node not found — resolve manually from node.driver-id in the loopback inspect above)")

### pw-dump: node runtime state  (id / name / state / latency / driver per node — bluez + stream rows are the interesting ones; a degraded node shows suspended/odd state here)
$(pw-dump 2>/dev/null | jq -r '.[] | select(.type=="PipeWire:Interface:Node") | [.id, .info.props["node.name"], .info.state, (.info.props["node.latency"] // "-"), (.info.props["node.driver-id"] // "-")] | @tsv' 2>/dev/null || echo "(pw-dump or jq unavailable)")

### journal  (user journal, last 30 min, bluetooth/audio relevant)
$(journalctl --user -u wireplumber --since '-30 min' --no-pager 2>/dev/null | tail -30 || true)
$(journalctl --user --since '-30 min' --no-pager 2>/dev/null | grep -iE 'bluez|pipewire|wireplumber|wfica|helium' | tail -25 || echo "(journal empty)")

### wpctl inspect: bluez device  (id=${dev_id:-not found})
$([ -n "$dev_id" ] && LC_ALL=C wpctl inspect "$dev_id" 2>/dev/null || echo "(bluez device not found)")

### Recent call-prep.log  (last 12 actions; GATHER = this snapshot was taken)
$(tail -12 "$LOG" 2>/dev/null)
EOF
	} > "$out"

	# Best-effort clipboard copy (Wayland first, then X11 fallbacks).
	clip=""
	if command -v wl-copy >/dev/null 2>&1; then clip="wl-copy"; wl-copy < "$out" 2>/dev/null
	elif command -v xclip >/dev/null 2>&1; then clip="xclip"; xclip -selection clipboard < "$out" 2>/dev/null
	elif command -v xsel >/dev/null 2>&1; then clip="xsel"; xsel --clipboard --input < "$out" 2>/dev/null
	fi
	if [ -n "$clip" ]; then
		clipmsg="(also copied to clipboard via $clip — just paste)"
	else
		clipmsg="(no clipboard tool found — open the file and copy manually)"
	fi
	notify "$(printf '📋 Diagnostics ready:\n%s\n%s' "$out" "$clipmsg")"
	printf '%s  GATHER     wrote %s  profile=%s sink_inputs=%s source_outputs=%s\n' \
		"$(date '+%F %T')" "$out" "$prof" "$si_n" "$so_n" >> "$LOG"
	printf '%s\n' "$out"
}

# ---- dispatch --------------------------------------------------------------

case "${1:-}" in
	prep) do_prep; exit ;;
	music) do_music; exit ;;
	toggle) QUIET=1; do_toggle; exit ;;
	r1) do_r1; exit ;;
	r2) do_r2; exit ;;
	r3) do_r3; exit ;;
	auto) do_auto; exit ;;
	r4) do_r4a; exit ;;
	r4b) do_r4b; exit ;;
	r4c) do_r4c; exit ;;
	status) do_status; exit ;;
	diag) do_diag; exit ;;
esac

items=(
	"🚑  AUTO · diagnose & fix (start here)"
	"📞  Prep for call (force HSP/HFP)"
	"🎵  Back to music (force A2DP)"
	"🎧  Recover R1 · suspend/resume (gentle)"
	"🎧  Recover R2 · move stream out & back"
	"🎧  Recover R3 · profile cycle off→HFP (aggressive)"
	"🔌  R4 · reconnect headset (link-layer, no buttons)"
	"📋  Gather diagnostics (prompt → /tmp + clipboard)"
	"📊  Show audio state (debug)"
)

sel="$(printf '%s\n' "${items[@]}" | rofi -dmenu -i -no-custom -p "🎧 Call Prep")"

case "$sel" in
	*"AUTO"*) do_auto ;;
	*"Prep for call"*) do_prep ;;
	*"Back to music"*) do_music ;;
	*"R1"*) do_r1 ;;
	*"R2"*) do_r2 ;;
	*"R3"*) do_r3 ;;
	*"R4"*) do_r4a ;;
	*"Gather diagnostics"*) do_diag ;;
	*"Show audio state"*) do_status ;;
	"") exit 0 ;;
esac
