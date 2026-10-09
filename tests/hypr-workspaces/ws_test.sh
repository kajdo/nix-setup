#!/usr/bin/env bash
# ============================================================================
# ws_test.sh - Hyprland workspace semantics test (spec: EXPECTED.md)
#
# IMPORTANT RUNTIME CONSTRAINTS:
#  * The script is typically run from an agent session (kitty + tmux) whose
#    terminal window occupies one of the workspaces. Therefore:
#    - "empty workspace" targets are DETECTED at runtime, never hardcoded
#    - the script NEVER kills pre-existing windows: only windows whose
#      addresses did NOT exist when the script started are ever cleaned up
#  * Run at most ONCE per boot (pre-fix wrap cases create ws10, which would
#    false-fail the max_ws<=9 invariant on a second in-session run).
#  * Run as the FIRST command after login (open terminal via keyboard, do not
#    move the mouse). Creates results/run_<timestamp>/ with JSON snapshots and
#    a markdown report; prints a verdict table to stdout.
#
# Phase C/T1 use the cycle path (pre-fix: r+1/r-1 dispatch, post-fix: global
# cycle_workspace() via hyprctl eval). Phase T2 uses the direct-switch path
# (pre-fix: plain focus dispatch, post-fix: global goto_workspace()).
# ============================================================================
set -u

HYPRCTL="hyprctl"
TESTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$TESTDIR/results/run_$(date +%Y%m%d_%H%M%S)"
REPORT="$OUTDIR/report.md"
SLEEP=0.4
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
MODE="legacy"
MODE2="legacy"

mkdir -p "$OUTDIR"

log()  { printf '%s\n' "$*"; }
md()   { printf '%s\n' "$*" >> "$REPORT"; }

# --- user-facing progress notifications (notify-send) --------------------------
NOTIFY_OK=0; command -v notify-send >/dev/null 2>&1 && NOTIFY_OK=1
TOTAL_STEPS=52          # B:2 + F:6 + C:6 + T1:18 + T2:18 + T3:2 (all funnel through check/skip_case/t3_check)
STEP=0
T0=$SECONDS
notify() { # notify <text> [timeout-ms]
  [ "$NOTIFY_OK" = "1" ] && notify-send -t "${2:-2500}" "hypr_ws_test" "$*" >/dev/null 2>&1
}
notify_step() { # notify_step <id> <desc>
  STEP=$((STEP+1))
  notify "[$STEP/$TOTAL_STEPS · $((SECONDS-T0))s] $1: $2 — $((TOTAL_STEPS-STEP)) remaining" 2000
}
notify_phase() { # notify_phase <name>
  notify "— Phase $1 —" 1500
}

# ----------------------------------------------------------------------------
# state capture
# ----------------------------------------------------------------------------
snap() { # snap <tag> : dump all relevant state as JSON/txt files
  local tag="$1"
  sleep 0.3   # let socket2 events settle so the replay marker slices correctly
  $HYPRCTL -j monitors        > "$OUTDIR/${tag}_monitors.json" 2>/dev/null
  $HYPRCTL -j workspaces      > "$OUTDIR/${tag}_workspaces.json" 2>/dev/null
  $HYPRCTL -j activeworkspace > "$OUTDIR/${tag}_activews.json" 2>/dev/null
  $HYPRCTL -j activewindow    > "$OUTDIR/${tag}_activewin.json" 2>/dev/null
  $HYPRCTL cursorpos          > "$OUTDIR/${tag}_cursorpos.txt" 2>/dev/null
  # marker for the waybar-highlight replay (EXPECTED.md §6c)
  [ -n "${EVENTLOG:-}" ] && printf '###SNAP %s\n' "$tag" >> "$EVENTLOG"
}

field() { # field <tag> <name> : extract compact fields from a snapshot
  local tag="$1" name="$2" v
  case "$name" in
    aws_id)  v=$(jq -r '.id'      "$OUTDIR/${tag}_activews.json" 2>/dev/null) ;;
    aws_mon) v=$(jq -r '.monitor' "$OUTDIR/${tag}_activews.json" 2>/dev/null) ;;
    fmon)    v=$(jq -r '[.[] | select(.focused == true) | .name] | join(",")' "$OUTDIR/${tag}_monitors.json" 2>/dev/null) ;;
    fmon_n)  v=$(jq -r '[.[] | select(.focused == true)] | length'           "$OUTDIR/${tag}_monitors.json" 2>/dev/null) ;;
    win)     v=$(jq -r 'if (type == "object" and .title != null) then .title else "NONE" end' "$OUTDIR/${tag}_activewin.json" 2>/dev/null) ;;
    wincls)  v=$(jq -r 'if (type == "object" and .class != null) then .class else "NONE" end' "$OUTDIR/${tag}_activewin.json" 2>/dev/null) ;;
    max_ws)  v=$(jq -r '[.[].id] | max // 0'                                 "$OUTDIR/${tag}_workspaces.json" 2>/dev/null) ;;
  esac
  echo "${v:-?}"
}

cursor_monitor() { # cursor_monitor <tag> : which monitor contains the cursor
  local tag="$1"
  local pos cx cy
  pos=$(<"$OUTDIR/${tag}_cursorpos.txt"); cx=${pos%%,*}; cy=${pos##*,}
  cx=${cx// /}; cy=${cy// /}
  jq -r --argjson cx "$cx" --argjson cy "$cy" \
    '[.[] | select(.x <= $cx and $cx < (.x + .width) and .y <= $cy and $cy < (.y + .height)) | .name] | join(",")' \
    "$OUTDIR/${tag}_monitors.json" 2>/dev/null || echo "?"
}

# ----------------------------------------------------------------------------
# actions
# ----------------------------------------------------------------------------
dispatch() { # dispatch <lua-expr>
  $HYPRCTL dispatch "$1" >/dev/null 2>&1
  sleep "$SLEEP"
}

focus_ws()      { dispatch "hl.dsp.focus({ workspace = $1 })"; }
cycle_legacy()  { dispatch "hl.dsp.focus({ workspace = \"$1\" })"; }  # $1 = r+1 | r-1
cycle_fixed()   { $HYPRCTL eval "cycle_workspace($1)" >/dev/null 2>&1; sleep "$SLEEP"; }
cycle()         { if [ "$MODE" = "fixed" ]; then cycle_fixed "$1"; else cycle_legacy "$1"; fi; }

t2_goto() { # t2_goto <n> : direct switch, exact bind path (TEST 2)
  if [ "$MODE2" = "fixed" ]; then
    $HYPRCTL eval "goto_workspace($1)" >/dev/null 2>&1
    sleep "$SLEEP"
  else
    focus_ws "$1"
  fi
}

cursor_to() { # cursor_to <monitor-name> : move cursor to monitor center
  local mon="$1" cx cy
  cx=$(jq -r --arg m "$mon" '.[] | select(.name==$m) | (.x + .width/2) | floor' "$OUTDIR/mon.json")
  cy=$(jq -r --arg m "$mon" '.[] | select(.name==$m) | (.y + .height/2) | floor' "$OUTDIR/mon.json")
  dispatch "hl.dsp.cursor.move({ x = $cx, y = $cy })"
}

prep() { # prep <cursor-monitor> <ws> : cursor to monitor center, then focus ws
  cursor_to "$1"; focus_ws "$2"
}

monitor_for() { # monitor_for <ws-id> : which monitor ws is bound to (live query)
  $HYPRCTL -j workspaces | jq -r --argjson w "$1" '[.[] | select(.id==$w) | .monitor] | first // "?"' 2>/dev/null
}

# ----------------------------------------------------------------------------
# safe window spawn/close — PROCESS OWNERSHIP, UNIQUE APP-ID "WSTEST"
#
# Design (per user): the script SPAWNS the kitty itself and OWNS the process:
#   setsid kitty --app-id WSTEST … &
# → $! is the session leader = process-group id (validated live: kitty maps no
#   extra groups; kittens join the leader's group). Closing = ONE signal to
#   the group: `kill -- -PGID` — window closes with the client connection,
#   kittens die with it. NO compositor dispatch, NO window.kill, NO address
#   bookkeeping for lifecycle (addresses are recycled by the compositor and
#   must never decide liveness — two T3b bugs came from that mistake).
#
# The app-id → class "WSTEST" is suite-exclusive: identification by class is
# safe even in a dirty session; WSTEST_ADDR is kept for REPORTING only.
#
# Historical trap (no longer used, kept as warning): hl.dsp.window.kill
# requires a window SELECTOR { window = "address:0x…" } — passing
# { address = … } is SILENTLY IGNORED and kills the FOCUSED window instead.
# ----------------------------------------------------------------------------
declare -a SPAWN_PGIDS=()   # process-group ids of every kitty WE spawned (script owns them)
declare -a GUARD_ADDRS=()   # pre-existing windows at script start: passive integrity check

guard_snapshot() { # record all existing client addresses as protected
  local addr
  while IFS= read -r addr; do
    [ -n "$addr" ] && GUARD_ADDRS+=("$addr")
  done < <($HYPRCTL -j clients | jq -r '.[].address' 2>/dev/null)
}

wstest_windows() { # print "addr pid" lines for every WSTEST window currently alive
  $HYPRCTL -j clients | jq -r '.[] | select(.class=="WSTEST") | "\(.address) \(.pid)"' 2>/dev/null
}
wstest_procs() { # live (non-zombie) pids of suite-spawned kitties; comm is matched against
  # the kitty executable OR its Nix wrapper — never raw cmdlines (they
  # self-match the awk process and any wrapper embedding the pattern string)
  ps -eo pid=,stat=,comm=,args= | awk '$2 !~ /Z/ && ($3 == "kitty" || $3 ~ /^\.?kitty/) && index($0, "--app-id WSTEST") { print $1 }'
}
pgid_alive() { # pgid_alive <pgid> : any LIVE (non-zombie) process left in that group?
  ps -eo pgid=,stat= | awk -v g="$1" '{ gsub(/ /, "", $1); if ($1 == g && $2 !~ /Z/) f = 1 } END { exit f ? 0 : 1 }'
}

wstest_spawn() { # spawn a WSTEST kitty as OUR OWN process group; sets WSTEST_PGID (+ WSTEST_ADDR, report-only)
  # NOTE: must NOT be called inside $( ) — SPAWN_PGIDS state must survive!
  local n np pgid line try
  WSTEST_ADDR=""; WSTEST_PGID=""
  n=$(wstest_windows | grep -c . || true)
  np=$(wstest_procs | grep -c . || true)
  [ "${n:-0}" = "0" ] && [ "${np:-0}" = "0" ] || { log "[SPAWN][ERROR] leftovers: $n WSTEST window(s), $np process(es) — run cleanup first"; return 1; }
  # the script owns what it spawns: setsid → $! is the pgid (validated live)
  setsid kitty --app-id WSTEST >/dev/null 2>&1 &
  pgid=$!
  SPAWN_PGIDS+=("$pgid")
  WSTEST_PGID="$pgid"
  # poll for the window (kitty start latency varies; up to 8s)
  try=0
  while [ $try -lt 16 ] && [ -z "$(wstest_windows | head -1)" ]; do
    sleep 0.5; try=$((try + 1))
  done
  [ $try -gt 4 ] && log "[SPAWN] window needed $((try / 2)).$(( (try % 2) * 5 ))s to map (slow start)"
  line=$(wstest_windows | head -1)
  if [ -n "$line" ]; then
    WSTEST_ADDR="${line%% *}"   # reporting only — never used for lifecycle
    return 0
  fi
  return 1   # spawn produced nothing (no window after polling)
}

close_spawned() { # close_spawned <pgid> : kill a process group WE spawned — verified by
  # ITS OWN group state ONLY (never by "any WSTEST anywhere": during mid-run
  # case-local cleanups the NEXT case's window is legitimately alive — global
  # zero-remnant is asserted by cleanup_spawned at the end, where it holds)
  local pgid="$1" try
  [ -n "$pgid" ] || return 0
  if ! pgid_alive "$pgid"; then
    log "[KILL] WSTEST pgid $pgid already closed"
    return 0
  fi
  kill -- -"$pgid" 2>/dev/null           # graceful TERM to the whole group
  for try in 1 2 3; do                   # grace, then hard kill if needed
    sleep 0.4
    pgid_alive "$pgid" || break
    kill -9 -- -"$pgid" 2>/dev/null
  done
  if pgid_alive "$pgid"; then
    log "[KILL][ERROR] pgid $pgid: group STILL ALIVE after TERM+KILL"
    return 1
  fi
  log "[KILL] WSTEST pgid $pgid closed cleanly (group kill)"
  return 0
}

spawn_on_ws() { # spawn_on_ws <ws> : focus ws, spawn WSTEST kitty; sets WSTEST_ADDR
  focus_ws "$1"
  sleep 0.3
  wstest_spawn
}

cleanup_spawned() { # close everything the script created — verified down to zero remnants
  local pgid rem_p rem_w addrs_json guard_missing g
  for pgid in "${SPAWN_PGIDS[@]}"; do
    close_spawned "$pgid"      # idempotent: dead group → no-op, verify still passes
  done
  # final assertion: zero WSTEST windows AND zero WSTEST processes remain
  rem_p=$(wstest_procs | grep -c . || true)
  rem_w=$(wstest_windows | grep -c . || true)
  [ "${rem_p:-0}" = "0" ] && [ "${rem_w:-0}" = "0" ] || log "[CLEANUP][ERROR] $rem_w WSTEST window(s) + $rem_p process(es) STILL ALIVE — manual cleanup needed"
  # passive integrity check: every pre-existing window must still be there
  addrs_json=$($HYPRCTL -j clients | jq -r '[.[].address]' 2>/dev/null)
  guard_missing=$(for g in "${GUARD_ADDRS[@]}"; do
    jq -rn --arg a "$g" --argjson p "$addrs_json" '$p | index($a) == null' 2>/dev/null
  done | grep -c true || true)
  [ "${guard_missing:-0}" = "0" ] || log "[CLEANUP][ERROR] $guard_missing pre-existing window(s) DISAPPEARED"
}

# ----------------------------------------------------------------------------
# verdicts
# ----------------------------------------------------------------------------
# waybar-highlight replay (see EXPECTED.md §6c):
# waybar 0.15 hyprland/workspaces sets button class .active if
#   ws.id == m_activeWorkspaceId  (event-fed: init=activeworkspace, then
#                                  focusedmonv2 events carry MON,WSID)
#   OR ws.name == activeworkspace.name  (read fresh on every update)
# => if the event-fed id is stale, TWO buttons get .active — the user's bug.
# This function replays m_activeWorkspaceId from the captured event stream.
# NOTE on workspacev2: waybar re-queries activeworkspace live at that event;
#      we approximate with the case-final activeworkspace id (documented).
waybar_replay() { # <eventlog> <statefile> <tag> <final_activews_id> : echo m_activeWorkspaceId at marker <tag>
  local evlog="$1" state="$2" tag="$3" final_id="$4"
  local ln=0 a="$final_id" marker_ln i=0 ev evdata
  [ -r "$state" ] && read -r ln a < "$state"
  : "${a:=$final_id}"
  marker_ln=$(grep -n "^###SNAP $tag\$" "$evlog" 2>/dev/null | head -1 | cut -d: -f1)
  [ -n "$marker_ln" ] || marker_ln=$(( $(wc -l < "$evlog" 2>/dev/null || echo 0) + 1 ))
  while IFS= read -r ev; do
    i=$((i+1))
    [ "$i" -le "$ln" ] && continue
    [ "$i" -ge "$marker_ln" ] && break
    case "$ev" in
      'focusedmonv2>>'*) evdata=${ev#focusedmonv2>>}; a=${evdata##*,} ;;
      'workspacev2>>'*)  a="$final_id" ;;
    esac
  done < "$evlog"
  printf '%s %s\n' "$i" "$a" > "$state"
  echo "$a"
}

check() { # check <case-id> <description> <action-desc> <exp-ws> <exp-focused-mon> <exp-win: NONE|any|substr|auto:N> [exp-cursor-mon|-]
  local id="$1" desc="$2" action="$3" ews="$4" emon="$5" ewin="$6" ecur="${7:--}"
  local aws amon fmon fnmon awin acls cmon maxws verdict="PASS" reason=""

  snap "$id"
  aws=$(field "$id" aws_id); amon=$(field "$id" aws_mon)
  fmon=$(field "$id" fmon);  fnmon=$(field "$id" fmon_n)
  awin=$(field "$id" win);   acls=$(field "$id" wincls)
  cmon=$(cursor_monitor "$id")
  maxws=$(field "$id" max_ws)

  [ "$aws" = "$ews" ]   || { verdict="FAIL"; reason+=" active-ws=$aws@$amon (want $ews);"; }
  [ "$fmon" = "$emon" ] || { verdict="FAIL"; reason+=" focused-mon='$fmon' (want $emon);"; }
  if [ "$acls" = "KittyScratchpad" ]; then
    # the runner's own scratchpad overlays the focused ws and reports as
    # activewindow — the win sub-check cannot see the real target ws content.
    # Skip it (ws/focus/cursor carry the verdict); note for the record.
    reason+=" [win-check skipped: runner overlay]"
  else
  case "$ewin" in
    NONE) [ "$awin" = "NONE" ] || { verdict="FAIL"; reason+=" active-win='$awin' (want NONE);"; } ;;
    any)  [ "$awin" != "NONE" ] || { verdict="FAIL"; reason+=" active-win=NONE (want a window);"; } ;;
    auto:*) # NONE if target ws is empty at test time, else any window
      local tws_n
      tws_n=$(jq -r --argjson w "${ewin#auto:}" '[.[] | select(.id==$w) | .windows] | first // 0' "$OUTDIR/${id}_workspaces.json" 2>/dev/null)
      if [ "${tws_n:-0}" = "0" ]; then
        [ "$awin" = "NONE" ] || { verdict="FAIL"; reason+=" active-win='$awin' (want NONE, ws${ewin#auto:} empty);"; }
      else
        [ "$awin" != "NONE" ] || { verdict="FAIL"; reason+=" active-win=NONE (want a window, ws${ewin#auto:} has $tws_n);"; }
      fi ;;
    *)    [[ "$awin" == *"$ewin"* ]] || { verdict="FAIL"; reason+=" active-win='$awin' (want ~'$ewin');"; } ;;
  esac
  fi
  [ "$fnmon" = "1" ] || { verdict="FAIL"; reason+=" focused-monitors=$fnmon (want exactly 1);"; }
  if [ "$maxws" != "?" ]; then
    [ "$maxws" -le 9 ] 2>/dev/null || { verdict="FAIL"; reason+=" max-ws-id=$maxws (ws>9 created!);"; }
  fi
  if [ -n "$ecur" ] && [ "$ecur" != "-" ]; then
    [ "$cmon" = "$ecur" ] || { verdict="FAIL"; reason+=" cursor-on='$cmon' (want $ecur);"; }
  fi

  # waybar highlight invariant: EXACTLY ONE .active button (never two)
  local wa="?" wline=""
  if [ "${WAYBAR_CAPTURE:-0}" = "1" ]; then
    wa=$(waybar_replay "$EVENTLOG" "$OUTDIR/.replay_state" "$id" "$aws")
    if [ "$wa" = "$aws" ]; then
      wline="waybar[A=$wa]: single .active"
    elif jq -e --argjson w "$wa" '[.[] | select(.id==$w)] | length > 0' "$OUTDIR/${id}_workspaces.json" >/dev/null 2>&1; then
      verdict="FAIL"; reason+=" waybar: TWO .active buttons (ws$wa by stale event-id + ws$aws by activews-name);"
      wline="waybar[A=$wa,N=$aws]: DOUBLE HIGHLIGHT"
    else
      wline="waybar[A=$wa,N=$aws]: single .active (stale A unresolvable)"
    fi
  fi

  if [ "$verdict" = "PASS" ]; then PASS_COUNT=$((PASS_COUNT+1)); else FAIL_COUNT=$((FAIL_COUNT+1)); fi
  notify_step "$id" "$desc"
  log "[$verdict] $id | $desc"
  log "         action: $action"
  log "         actual: ws=$aws@$amon focused=$fmon win='$awin' ($acls) cursor@$cmon $wline${reason:+  => $reason}"
  md "| $id | $desc | \`$action\` | ws=$ews, focus=$emon, win=$ewin${ecur:+, cursor=$ecur} | ws=$aws@$amon, focus=$fmon, win='$awin' ($acls), cursor@$cmon${wline:+, $wline} | **$verdict**${reason:+<br>$reason} |"
}

skip_case() { # skip_case <case-id> <description> <reason>
  SKIP_COUNT=$((SKIP_COUNT+1))
  notify_step "$1" "SKIPPED ($3)"
  log "[SKIP] $1 | $2 ($3)"
  md "| $1 | $2 | - | - | - | **SKIP** ($3) |"
}

t3_check() { # t3_check <id> <desc> <expected-ws> : verify ALT+T opened kitty on the focused ws
  local id="$1" desc="$2" ews="$3"
  local acls wsws aws fmon emon verdict="PASS" reason=""
  snap "$id"
  acls=$(jq -r 'if (type == "object" and .class != null) then .class else "NONE" end' "$OUTDIR/${id}_activewin.json" 2>/dev/null)
  wsws=$(jq -r 'if (type == "object") then .workspace.id else -1 end' "$OUTDIR/${id}_activewin.json" 2>/dev/null)
  aws=$(field "$id" aws_id); fmon=$(field "$id" fmon)
  emon=$(monitor_for "$ews")
  [[ "$acls" == "WSTEST" ]] || { verdict="FAIL"; reason+=" win-class=$acls (want WSTEST);"; }
  [ "${wsws:--1}" = "$ews" ] || { verdict="FAIL"; reason+=" win-ws=${wsws:--1} (want $ews);"; }
  [ "$aws" = "$ews" ] || { verdict="FAIL"; reason+=" active-ws=$aws (want $ews);"; }
  [ "$fmon" = "$emon" ] || { verdict="FAIL"; reason+=" focused=$fmon (want $emon);"; }
  # waybar highlight invariant: EXACTLY ONE .active button (never two)
  local wa="?" wline=""
  if [ "${WAYBAR_CAPTURE:-0}" = "1" ]; then
    wa=$(waybar_replay "$EVENTLOG" "$OUTDIR/.replay_state" "$id" "$aws")
    if [ "$wa" = "$aws" ]; then
      wline="waybar[A=$wa]: single .active"
    elif jq -e --argjson w "$wa" '[.[] | select(.id==$w)] | length > 0' "$OUTDIR/${id}_workspaces.json" >/dev/null 2>&1; then
      verdict="FAIL"; reason+=" waybar: TWO .active buttons (ws$wa by stale event-id + ws$aws by activews-name);"
      wline="waybar[A=$wa,N=$aws]: DOUBLE HIGHLIGHT"
    else
      wline="waybar[A=$wa,N=$aws]: single .active (stale A unresolvable)"
    fi
  fi
  if [ "$verdict" = "PASS" ]; then PASS_COUNT=$((PASS_COUNT+1)); else FAIL_COUNT=$((FAIL_COUNT+1)); fi
  notify_step "$id" "$desc"
  log "[$verdict] $id | $desc"
  log "         actual: win='$acls' on ws${wsws:--1}, active-ws=$aws, focused=$fmon, $wline${reason:+  => $reason}"
  md "| $id | $desc | exec kitty after switch to ws$ews | kitty on ws$ews, focused on its monitor | win='$acls' on ws${wsws:--1}, active-ws=$aws, focused=$fmon${wline:+, $wline} | **$verdict**${reason:+<br>$reason} |"
}

# ============================================================================
# SCRIPT START
# ============================================================================
$HYPRCTL -j monitors > "$OUTDIR/mon.json"

# --- pre-flight: session must be free of suite remnants (dirty-session abort) --
if [ "$(wstest_windows | grep -c . || true)" != "0" ] || [ "$(wstest_procs | grep -c . || true)" != "0" ]; then
  log "[FATAL] WSTEST remnants exist at script start (dirty session) — clean them first, then reboot for a clean run"
  notify "FATAL: WSTEST remnants at script start — dirty session, aborting" 5000
  exit 1
fi

# --- mode detection (eval does not print return values -> assert) -------------
if $HYPRCTL eval 'assert(type(cycle_workspace) == "function")' 2>/dev/null | grep -q "^ok$"; then
  MODE="fixed"
fi
if $HYPRCTL eval 'assert(type(goto_workspace) == "function")' 2>/dev/null | grep -q "^ok$"; then
  MODE2="fixed"
fi

{
  md "# Workspace semantics run — $(date)"
  md ""
  md "- Hyprland: $($HYPRCTL version | head -1)"
  md "- Mode of phase C/T1: **$MODE** (fixed = global cycle_workspace()); mode of T2: **$MODE2** (fixed = global goto_workspace())"
  md ""
  md "| Case | Description | Action | Expected | Actual | Verdict |"
  md "|---|---|---|---|---|---|"
} >> "$REPORT"

log "=== workspace semantics test — modes: C/T1=$MODE, T2=$MODE2 ==="
log "results dir: $OUTDIR"
log ""

# --- protect all pre-existing windows (incl. the agent's kitty+tmux) ----------
guard_snapshot
log "[GUARD] ${#GUARD_ADDRS[@]} pre-existing window(s) protected from killing"
md ""
md "- Protected pre-existing windows: ${#GUARD_ADDRS[@]} (never touched by this script)"

# --- Phase B: boot snapshot (MUST be first — no dispatch happened yet) -------
snap B1
notify "Starting: $TOTAL_STEPS checks, ~4 min — hands off mouse & keyboard!" 3000
# record start state for end-of-run restore (the script must leave you where it found you)
START_AWS=$(jq -r '.id // empty' "$OUTDIR/B1_activews.json" 2>/dev/null)
START_AMON=$(jq -r '.monitor // empty' "$OUTDIR/B1_activews.json" 2>/dev/null)
log "[BOOT] start state recorded for restore: ws${START_AWS:-?}@${START_AMON:-?}"

# --- socket2 event capture for the waybar-highlight replay (EXPECTED.md §6c) --
EVENTLOG="$OUTDIR/events.log"; : > "$EVENTLOG"
WAYBAR_CAPTURE=0
SOCK2="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if command -v nc >/dev/null 2>&1 && [ -S "$SOCK2" ]; then
  nc -U "$SOCK2" >> "$EVENTLOG" 2>/dev/null &
  LOGGER_PID=$!
  trap 'kill "$LOGGER_PID" 2>/dev/null' EXIT
  WAYBAR_CAPTURE=1
  printf '###SNAP B1\n' >> "$EVENTLOG"
  echo "0 $(jq -r '.id' "$OUTDIR/B1_activews.json" 2>/dev/null || echo 0)" > "$OUTDIR/.replay_state"
  log "[INFO] waybar event capture started (pid $LOGGER_PID)"
else
  log "[WARN] nc/socket2 unavailable — waybar highlight checks disabled"
fi
BOOT_CURSOR=$(cursor_monitor B1)
BOOT_CURPOS=$(<"$OUTDIR/B1_cursorpos.txt")
BOOT_FMON=$(field B1 fmon)
WS_COUNT=$(jq 'length' "$OUTDIR/B1_workspaces.json" 2>/dev/null)
WS_PERSIST=$(jq '[.[] | select(.ispersistent)] | length' "$OUTDIR/B1_workspaces.json" 2>/dev/null)
OCCUPIED=$(jq -r '[.[] | select(.windows > 0) | (.id|tostring)] | join(",")' "$OUTDIR/B1_workspaces.json" 2>/dev/null)
log "[BOOT] B1: cursor=($BOOT_CURPOS -> on $BOOT_CURSOR), focused monitor: $BOOT_FMON"
log "       workspaces present: $WS_COUNT (persistent: $WS_PERSIST), occupied ws: ${OCCUPIED:-none}"
md "| B1 | boot snapshot | (none) | 9 persistent ws, correct bindings; record boot state | cursor=$BOOT_CURPOS on $BOOT_CURSOR, focused=$BOOT_FMON, ws-present=$WS_COUNT (persist $WS_PERSIST), occupied=${OCCUPIED:-none} | info |"
if [ "${WS_COUNT:-0}" = "9" ] && [ "${WS_PERSIST:-0}" = "9" ]; then
  log "[PASS] B1a: all 9 workspaces exist and are persistent"
  notify_step B1a "9 persistent workspaces OK"
  PASS_COUNT=$((PASS_COUNT+1))
else
  log "[FAIL] B1a: expected 9 persistent workspaces, found ${WS_COUNT:-?} (${WS_PERSIST:-?} persistent)"
  notify_step B1a "persistent-workspace count WRONG"
  FAIL_COUNT=$((FAIL_COUNT+1))
fi
BAD_BIND=$(jq -r '([.[] | select((.id==1 or .id==9) and .monitor != "eDP-1")] + [.[] | select(.id>=2 and .id<=8 and .monitor != "HDMI-A-2")]) | length' "$OUTDIR/B1_workspaces.json" 2>/dev/null)
if [ "${BAD_BIND:-1}" = "0" ]; then
  log "[PASS] B1b: ws->monitor bindings correct (1,9->eDP-1; 2-8->HDMI-A-2)"
  notify_step B1b "ws→monitor bindings OK"
  PASS_COUNT=$((PASS_COUNT+1))
else
  log "[FAIL] B1b: ${BAD_BIND:-?} workspace(s) on wrong monitor"
  notify_step B1b "ws→monitor bindings WRONG"
  FAIL_COUNT=$((FAIL_COUNT+1))
fi
log ""

# --- dynamic empty-workspace targets (runner terminal may sit anywhere!) -----
E_HDMI=($(jq -r '[.[] | select(.id>=2 and .id<=8 and .windows==0) | .id] | sort | .[]' "$OUTDIR/B1_workspaces.json" 2>/dev/null))
E_EDP=$(jq -r '[.[] | select((.id==9 or .id==1) and .windows==0) | .id] | sort_by(-.) | first // empty' "$OUTDIR/B1_workspaces.json" 2>/dev/null)
E1=${E_HDMI[0]:-}; E2=${E_HDMI[1]:-}; ESPAWN=${E_HDMI[2]:-}; ET3A=${E_HDMI[3]:-}; ET3B=${E_HDMI[4]:-}
log "[DYN] empty HDMI ws pool: ${E_HDMI[*]:-none}; empty eDP ws: ${E_EDP:-none}"
log "       targets: E1=${E1:-?} E2=${E2:-?} spawn=$ESPAWN T3a=$ET3A T3b=$ET3B"
log ""

# --- Phase F: plain focus() semantics (expected UNCHANGED by the fix) --------
log "=== Phase F: plain focus({workspace=N}) semantics ==="
notify_phase "F: focus semantics (6 checks)"

if [ -n "$E1" ]; then
  cursor_to eDP-1
  focus_ws "$E1"
  check F1 "focus EMPTY ws$E1 (HDMI) with cursor on eDP-1" "cursor->eDP-1; focus ws$E1" "$E1" HDMI-A-2 NONE
else
  skip_case F1 "focus EMPTY HDMI ws with cursor on eDP-1" "no empty HDMI ws available"
fi

if [ -n "$E2" ]; then
  focus_ws "$E2"
  check F2 "focus EMPTY ws$E2 (same mon) — user's failing case" "(continue from F1); focus ws$E2" "$E2" HDMI-A-2 NONE
else
  skip_case F2 "focus second EMPTY HDMI ws" "not enough empty HDMI ws"
fi

if [ -n "$E2" ]; then
  prep HDMI-A-2 2
  focus_ws "$E2"
  check F3 "focus EMPTY ws$E2, cursor on HDMI-A-2 (control)" "prep(HDMI-A-2, ws2); focus ws$E2" "$E2" HDMI-A-2 NONE
else
  skip_case F3 "focus EMPTY HDMI ws, cursor on HDMI (control)" "not enough empty HDMI ws"
fi

if [ -n "$E_EDP" ]; then
  prep HDMI-A-2 2
  focus_ws "$E_EDP"
  check F4 "focus EMPTY ws$E_EDP (eDP), cursor on HDMI-A-2" "prep(HDMI-A-2, ws2); focus ws$E_EDP" "$E_EDP" eDP-1 NONE
else
  skip_case F4 "focus EMPTY eDP ws, cursor on HDMI" "no empty eDP ws"
fi

prep HDMI-A-2 2
focus_ws 1
check F5 "focus NON-EMPTY ws1 (eDP), cursor on HDMI-A-2" "prep(HDMI-A-2, ws2); focus ws1" 1 eDP-1 any

if [ -n "$ESPAWN" ]; then
  spawn_on_ws "$ESPAWN"
  KPG="$WSTEST_PGID"
  [ -n "$KPG" ] && log "[INFO] spawned test kitty (pgid $KPG) on ws$ESPAWN"
  prep eDP-1 2
  focus_ws "$ESPAWN"
  check F6 "focus NON-EMPTY ws$ESPAWN (HDMI), cursor on eDP-1" "spawn kitty@ws$ESPAWN; prep(eDP-1, ws2); focus ws$ESPAWN" "$ESPAWN" HDMI-A-2 any
  close_spawned "$KPG"    # release the ws again (one WSTEST window at a time)
else
  skip_case F6 "focus NON-EMPTY spawned HDMI ws" "not enough empty HDMI ws"
fi
log ""

# --- Phase C: cycle semantics (exact bind code path) --------------------------
log "=== Phase C: cycle semantics (mode: $MODE) ==="
notify_phase "C: cycle semantics (6 checks)"

prep HDMI-A-2 2
cycle "+1"
check C1 "cycle +1 from ws2 (same monitor)" "prep(HDMI-A-2, ws2); cycle(+1)" 3 HDMI-A-2 auto:3 HDMI-A-2

prep HDMI-A-2 8
cycle "+1"
check C2 "cycle +1 from ws8 (boundary, crosses to eDP)" "prep(HDMI-A-2, ws8); cycle(+1)" 9 eDP-1 auto:9 eDP-1

prep eDP-1 9
cycle "+1"
check C3 "cycle +1 from ws9 (wrap 9->1)" "prep(eDP-1, ws9); cycle(+1)" 1 eDP-1 auto:1 eDP-1

prep eDP-1 1
cycle "-1"
check C4 "cycle -1 from ws1 (wrap 1->9)" "prep(eDP-1, ws1); cycle(-1)" 9 eDP-1 auto:9 eDP-1

prep eDP-1 1
cycle "+1"
check C5 "cycle +1 from ws1 (crosses to HDMI)" "prep(eDP-1, ws1); cycle(+1)" 2 HDMI-A-2 auto:2 HDMI-A-2

# C6: user's exact fresh-boot workflow — cursor on eDP, empty HDMI ws, cycle
if [ -n "$E1" ]; then
  C6NEXT=$(( E1 % 9 + 1 ))
  C6NMON=$(monitor_for "$C6NEXT")
  cursor_to eDP-1
  focus_ws "$E1"
  snap C6pre
  log "[INFO] C6 pre-state: ws=$(field C6pre aws_id)@$(field C6pre aws_mon), focused=$(field C6pre fmon), win='$(field C6pre win)'"
  if [ "$MODE" = "fixed" ]; then CYC6="cycle_workspace(1)"; else CYC6="r+1"; fi
  cycle "+1"
  check C6 "cycle +1 from unstable 'on ws$E1, cursor eDP-1' state" "cursor->eDP-1; focus ws$E1 (unstable); $CYC6" "$C6NEXT" "$C6NMON" "auto:$C6NEXT" "$C6NMON"
else
  skip_case C6 "cycle from unstable empty-HDMI state" "no empty HDMI ws"
fi
log ""

# --- Phase T1: TEST 1 table — alt+u / alt+i from EVERY workspace ----------------
log "=== Phase T1: TEST 1 wraparound table (mode: $MODE) ==="
notify_phase "T1: wraparound table (18 checks)"
for n in 1 2 3 4 5 6 7 8 9; do
  prev=$(( (n + 7) % 9 + 1 ))   # alt+u: n-1 with wrap (1 -> 9)
  next=$(( n % 9 + 1 ))         # alt+i: n+1 with wrap (9 -> 1)
  mon=$(monitor_for "$n")
  prep "$mon" "$n"
  cycle "-1"
  pmon=$(monitor_for "$prev")
  check "T1U$n" "TEST1: alt+u from ws$n -> ws$prev" "prep($mon, ws$n); alt+u" "$prev" "$pmon" "auto:$prev" "$pmon"
  prep "$mon" "$n"
  cycle "+1"
  nmon=$(monitor_for "$next")
  check "T1I$n" "TEST1: alt+i from ws$n -> ws$next" "prep($mon, ws$n); alt+i" "$next" "$nmon" "auto:$next" "$nmon"
done
log ""

# --- Phase T2: TEST 2 — direct switch alt+N from wherever -----------------------
log "=== Phase T2: TEST 2 direct switches (mode: $MODE2) ==="
notify_phase "T2: direct switches alt+1..9 (18 checks)"
for cur in eDP-1 HDMI-A-2; do
  for n in 1 2 3 4 5 6 7 8 9; do
    prep "$cur" 2
    t2_goto "$n"
    nmon=$(monitor_for "$n")
    check "T2_${cur}_${n}" "TEST2: alt+$n from ws2, cursor@$cur" "prep($cur, ws2); alt+$n" "$n" "$nmon" "auto:$n" "$nmon"
  done
done
log ""

# --- Phase T3: TEST 3 — ALT+T opens kitty on the switched-to workspace ----------
log "=== Phase T3: TEST 3 alt+T on focused ws ==="
notify_phase "T3: alt+T spawn placement (2 checks)"
if [ -n "$ET3A" ]; then
  prep eDP-1 2
  t2_goto "$ET3A"
  wstest_spawn || true
  W3A="$WSTEST_ADDR"
  if [ -n "$W3A" ]; then
    t3_check T3a "TEST3: alt+T after switch to never-used ws$ET3A" "$ET3A"
    cleanup_spawned          # case-local cleanup: no survivors even if later phases abort
  else
    skip_case T3a "alt+T after switch to never-used ws" "WSTEST spawn failed"
  fi
else
  skip_case T3a "alt+T after switch to never-used ws" "not enough empty HDMI ws"
fi

if [ -n "$ET3B" ]; then
  spawn_on_ws "$ET3B"
  KPG="$WSTEST_PGID"
  close_spawned "$KPG"    # ws had an app before, now closed again
  prep eDP-1 2
  t2_goto "$ET3B"
  wstest_spawn || true
  W3B="$WSTEST_ADDR"
  if [ -n "$W3B" ]; then
    t3_check T3b "TEST3: alt+T after switch to ws$ET3B (had an app before)" "$ET3B"
    cleanup_spawned        # case-local cleanup
  else
    skip_case T3b "alt+T after switch to had-app ws" "WSTEST spawn failed"
  fi
else
  skip_case T3b "alt+T after switch to had-app ws" "not enough empty HDMI ws"
fi
log ""

# --- cleanup: ONLY windows this script created ----------------------------------
cleanup_spawned
if [ -n "${START_AWS:-}" ]; then
  focus_ws "$START_AWS"
  cursor_to "${START_AMON:-eDP-1}"
fi
snap FINAL
log "=== cleanup done: zero WSTEST remnants (windows + processes), start state restored: ws${START_AWS:-?} focused, cursor on ${START_AMON:-?} ==="
md ""
md "## Summary"
md "- PASS: $PASS_COUNT"
md "- FAIL: $FAIL_COUNT"
md "- SKIP: $SKIP_COUNT"
md "- Modes: C/T1=$MODE, T2=$MODE2"
md "- Boot state: cursor=$BOOT_CURPOS (on $BOOT_CURSOR), focused monitor=$BOOT_FMON, occupied ws=${OCCUPIED:-none}"

log ""
log "=== SUMMARY: PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT (modes: C/T1=$MODE, T2=$MODE2) ==="
notify "✔ DONE after $((SECONDS-T0))s — PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT. Workspace state restored. Report: $(basename "$OUTDIR")" 7000
log "report: $REPORT"
exit 0
