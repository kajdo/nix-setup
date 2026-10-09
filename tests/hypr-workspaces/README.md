# Hyprland Workspace-Switching — Test Suite

Automated regression suite for dwm-style workspace behavior in Hyprland
(v0.56.2, Lua config) on a dual-monitor setup. It verifies the three binding
user-acceptance tests plus compositor-level semantics and the waybar
highlight invariant.

## Why this exists

Observed bugs (all reproduced & root-caused, see `ANALYSIS-baseline.md`):

1. Switching to an **empty** workspace on the *other* monitor leaves keyboard
   focus stolen by the monitor the cursor is on (the switch "doesn't work").
2. Arithmetic cycling `alt+i` / `alt+u` has **no wraparound**:
   `9 → +1` creates **ws10**, `1 → -1` is a no-op.
3. The cursor **never warps** to the target monitor on cross-monitor switches.
4. Waybar intermittently shows **two** highlighted workspaces (never allowed).

## System under test

| Item | Value |
|---|---|
| Compositor | Hyprland v0.56.2, Lua config (`configProvider: lua`) |
| Config | `nixos/home-manager/config/hypr/hyprland.lua` (live via HM symlink) |
| Monitors | eDP-1 @ -1920x0, HDMI-A-2 @ 0x0 (both 1920×1080) |
| Workspaces | ws1, ws9 → eDP-1; ws2–8 → HDMI-A-2; persistent 1–9 |
| Bar | waybar v0.15.0, module `hyprland/workspaces`, `all-outputs: true` |

## Terminology

- **active ws (per monitor)** — the workspace shown on that monitor
  (`hyprctl -j monitors → .activeWorkspace.id`)
- **focused monitor** — the one with keyboard focus (exactly one,
  `monitors → .focused == true`)
- **active ws (global)** — `hyprctl activeworkspace` = active ws **of the
  focused monitor**; waybar's `.active` class tracks this
- **active window** — window with keyboard focus (may be *none*)

## Target spec (S1–S7)

- **S1** Fixed set: exactly ws1–9 exist and persist; **ws10 is never created**
- **S2** `ALT/mainMod + 1..9` switches to ws N **from anywhere**:
  N becomes active on its monitor, keyboard focus lands on that monitor
- **S3** Number binds are exactly keys 1–9 (key-0 → ws10 dropped)
- **S4** `ALT/mainMod + I/U` (and mainMod+scroll) cycle ±1 with **wraparound
  9↔1**, global arithmetic
- **S5** On any switch, the **cursor warps to the target monitor** (dwm-style)
- **S6** `ALT+T` spawns the terminal **on the switched-to workspace**
- **S7** Waybar shows **exactly one** highlighted workspace at all times

## Root causes (measured, source-anchored)

1. **Focus theft**: switching to an empty ws clears focus
   (`fullWindowFocus(nullptr)`), then `follow_mouse=1` + `simulateMouseMovement()`
   re-grabs a window under the cursor on the *other* monitor; `no_warps=true`
   keeps the cursor parked. Works only when the target ws has a window or the
   cursor is already on the target monitor.
2. **No wraparound**: `r+1`/`r-1` arithmetic is global and unbounded
   (`9+1 → ws10`, `1-1 → no-op`).
3. **Waybar double-highlight**: waybar's `m_activeWorkspaceId` is event-fed
   (`focusedmonv2`); if it goes stale mid-switch, one button matches by *id*
   and another by *name* → two `.active` buttons.

## Files

| File | Purpose |
|---|---|
| `ws_test.sh` | The suite (52 checks, phases B/F/C/T1/T2/T3 + waybar replay) |
| `test_waybar_replay.sh` | Unit test for the waybar replay logic (fixtures only) |
| `EXPECTED.md.spec-source` | Original working spec (historical reference) |
| `ANALYSIS-baseline.md` | Fresh-boot baseline results + implementation proposal |
| `results/` | Run artifacts (gitignored; baseline `report.md`+`events.log` kept) |

## How to run

1. **Reboot** (clean state; Hyprland restores last-active-ws per monitor!)
2. Open the tmux-scratchpad kitty, start the agent, run:
   `tests/hypr-workspaces/ws_test.sh`
3. **Hands off mouse/keyboard** for the ~4 min runtime — progress is announced
   via `notify-send`: phase changes, `[step/52 · elapsed] id — N remaining`
   for every check, and a final `✔ DONE` summary
4. **At most one run per boot** — pre-fix cases create ws10, which would
   false-fail the `max-ws ≤ 9` invariant on a second run

Mode is auto-detected: pre-fix (bind dispatchers) vs post-fix (global
`goto_workspace`/`cycle_workspace` via `hyprctl eval` = exact bind code path).

## Safety model (runner executes from inside the tested session)

- All script-spawned windows run as `kitty --app-id WSTEST` → class `WSTEST`
  can never collide with user windows, however dirty the session
- `pid`+address are recorded **at spawn time**; cleanup kills **exactly those
  pids** (selector-kill + SIGTERM), verifying per kill: window gone, pid dead,
  **every pre-existing window still present** (abort on any anomaly)
- Exactly one WSTEST window alive at any time; the spawner refuses otherwise
- Nothing is ever selected by "which kitties exist now" (addresses are
  recycled by the compositor; kitty-count reasoning is meaningless)
- ⚠ `hl.dsp.window.kill({ address = … })` is **silently ignored** and kills
  the **focused window** — the correct form is a selector:
  `{ window = "address:0x…" }` (source: `LuaBindingsDispatchers.cpp → hlWindowKill`)
- Manual `hyprctl … kill` outside the script is forbidden
- Known measurement limit: the runner's own scratchpad (class
  `KittyScratchpad`) can overlay the focused ws and report as `activewindow`;
  the `win` sub-check is skipped in that case (ws/focus/cursor carry the
  verdict) and the skip is noted in the report

## Checks & acceptance

52 checks: B1 boot snapshot, F1–F6 focus semantics, C1–C6 cycle path,
T1×18 wrap table, T2×18 alt+1..9 from both cursor positions, T3a/b alt+T
spawn placement. Every check also asserts the **waybar invariant**
(exactly one `.active` button == expected ws, via event-stream replay of
waybar's algorithm) and `max-ws ≤ 9`.

**Fix acceptance**: all C/T1/T2/T3 checks PASS on two consecutive reboot
cycles, F-phase unchanged (plain dispatcher semantics stay), manual checklist
(see `ANALYSIS-baseline.md`) green.
