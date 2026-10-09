#!/usr/bin/env bash
# Unit test for waybar_replay() — extracted verbatim from ws_test.sh and run
# against a synthetic event log. No compositor interaction.
# Usage: test_waybar_replay.sh
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- extract the function from ws_test.sh (single source of truth) ----------
sed -n '/^# waybar-highlight replay/,/^check() {/p' "$SCRIPT_DIR/ws_test.sh" | sed '$d' > "$WORK/func.sh"
grep -q "^waybar_replay()" "$WORK/func.sh" || { echo "FAIL: extraction"; exit 1; }
source "$WORK/func.sh"

# --- fixture -----------------------------------------------------------------
cat > "$WORK/events.log" <<'EOF'
focusedmonv2>>HDMI-A-2,5
###SNAP F1
workspacev2>>7
focusedmonv2>>eDP-1,1
###SNAP F2
someotherevent>>ignored,data
focusedmonv2>>HDMI-A-2,9
###SNAP F3
EOF
STATE="$WORK/state"
echo "0 2" > "$STATE"   # waybar init: A = ws2

fail=0
# F1: slice = line 1 only -> A=5; state advances to marker line 2
a=$(waybar_replay "$WORK/events.log" "$STATE" F1 3)
[ "$a" = "5" ] || { echo "FAIL F1: got A=$a want 5"; fail=1; }

# F2: slice = lines 3-4: workspacev2->A=final(7), then focusedmonv2->A=1
a=$(waybar_replay "$WORK/events.log" "$STATE" F2 7)
[ "$a" = "1" ] || { echo "FAIL F2: got A=$a want 1"; fail=1; }

# F3: slice = lines 6-7: ignored event, then focusedmonv2->A=9
a=$(waybar_replay "$WORK/events.log" "$STATE" F3 9)
[ "$a" = "9" ] || { echo "FAIL F3: got A=$a want 9"; fail=1; }

# unknown marker: nothing processed, A unchanged
a=$(waybar_replay "$WORK/events.log" "$STATE" NOPE 9)
[ "$a" = "9" ] || { echo "FAIL NOPE: got A=$a want 9"; fail=1; }

# re-processing same marker must be idempotent (state line count)
a=$(waybar_replay "$WORK/events.log" "$STATE" F3 9)
[ "$a" = "9" ] || { echo "FAIL idempotent: got A=$a want 9"; fail=1; }

[ "$fail" = "0" ] && echo "ALL WAYBAR_REPLAY UNIT TESTS PASS" || exit 1
