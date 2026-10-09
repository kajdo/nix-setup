# Baseline Analysis & Implementation Proposal — Workspace Switching

**Run:** `results/BASELINE_BOOT3` (fresh boot 2026-02-10, single clean run, hands-off)
> **DEMODED to failed-baseline record** — T3b SKIPped due to a script bug
> (incomplete process closure, §7: only the recorded pid was closed, a second
> WSTEST process survived; cleanup also failed to restore the start
> workspace). Defect evidence itself is valid and identical to all prior
> runs; but the baseline gate requires a clean 52-check run.
> **FINAL BASELINE: next fresh-boot run with the hardened script** (§7 fixes:
> process sweep to zero remnants, pre-flight dirty-session abort, start-state
> restore).
>
> History: BOOT1 (2026-02-05, 24/28/0) = fresh boot but pre-amendment script
> (2 runner artifacts: F6 spawn-subshell, T2_HDMI-2_2 overlay);
> `results/VALIDATION_SAMEBOOT` (27/25/0) = full-suite validation of the
> amended script but same-boot rerun after an aborted first attempt —
> disqualified as baseline on protocol, kept as evidence. Per-case counts
> below are corrected against authoritative log recounts.
**Config under test:** `nixos/home-manager/config/hypr/hyprland.lua` @ current `main`
**Companion spec:** `README.md` (S1–S7) · raw report: `results/BASELINE_BOOT3/report.md`

## 1. Boot state (B1, BASELINE_BOOT3)

- Cursor −960,540 on eDP-1, focused=eDP-1, active ws=1, occupied: ws1 (runner terminal)
- **B1a FAIL: ws10 existed at boot** (10 workspaces, 9 persistent) — the previous
  session's leaked ws10 is **restored across reboots**; confirmed on every true
  fresh boot (BOOT1, BOOT3). Empty+inactive → auto-destroys during the run.
  S1 violation is sticky until ws10 stops being created.

## 2. Failure map — all 25 genuine FAILs reduce to 3 measured defects

### Defect A — cross-monitor focus theft (empty target, cursor elsewhere)
Empty target ws → focus cleared → `follow_mouse=1` re-grabs a window under the
cursor on the *other* monitor; `no_warps=true` keeps the cursor parked.

| Phase | Failing cases (BOOT3, corrected) | Evidence |
|---|---|---|
| B | B1a | 10 workspaces at boot (ws10 restored) |
| F | F1, F2 (eDP→empty HDMI), F4 (HDMI→empty eDP, mirrored) | switch "doesn't happen": activews stays on cursor's monitor (F3/F5/F6 controls pass) |
| C | C2 (8→9), C5 (1→2), C6 | same |
| T1 | I1 (1→2), U1 (−1 from 1†), U2†, I8, U9 (8↔9 boundary), I9 | same |
| T2 | eDP_2..8 (7×), HDMI_1†, HDMI_9 | **every** cross-monitor alt+N with cursor on other monitor fails; **every** same-monitor one passes (eDP_1, eDP_9, HDMI_2..8 pass) |
| T3 | T3a | alt+T kitty landed on ws9 (stolen focus ws), not target 5; T3b SKIP'd (runner incident §7) |

† = same-defect family: HDMI_1 fails *only* on cursor (switch worked — ws1
non-empty); T1U2 same (2→1 works, cursor not warped).

### Defect B — no wraparound (unbounded arithmetic)
C3 & T1I9: `9 + 1` → **creates ws10** (max-ws≤9 invariant FAIL; becomes
boot-restored next session, see §1). C4 & T1U1: `1 − 1` → no-op.

### Defect C — cursor never warps to target monitor
Every successful cross-monitor switch leaves the cursor behind
(T1U2, T2_HDMI_1 cursor-only FAILs; also embedded in all Defect-A rows).

**Runner artifacts (not defects):** BOOT1's T2_HDMI-2_2 FAILed only on
`active-win='tmux'` — the runner's own scratchpad overlay reports as active
window on the focused ws. Fixed in the amended script (win sub-check skipped
for class `KittyScratchpad`); BOOT3: T2_HDMI-2_2 PASSes. Same for BOOT1's F6
(spawn ran in a subshell pre-fix): F6 passes in BOOT3.

## 7. Runner incident (BOOT3, T3b): incomplete process closure — FIXED

After T3a's verdict the script closed the spawned kitty's window and killed
the ONE recorded pid, verified address gone + pid dead — but a SECOND WSTEST
process (different pid) was still running and re-surfaced as a window under
the recycled address (events.log: `closewindow>>A` … `openwindow>>A`). The
script failed its own contract: **close everything you spawned**. The
one-at-a-time interlock then correctly refused T3b's spawns → SKIP, and the
leftover survived cleanup. Post-run the leftover was removed by pid with
before/after proof.

**Fixes (applied AFTER the BOOT3 run, to be proven by the final baseline):**
1. `wstest_procs()` — every process carrying the suite-exclusive
   `kitty --app-id WSTEST` cmdline is script-spawned by construction;
   `safe_kill` now SIGKILLs **all** of them and verifies **zero WSTEST
   windows AND zero WSTEST processes** (recorded pid alone is insufficient)
2. `wstest_spawn` refuses when ANY WSTEST window OR process lingers
3. Pre-flight abort: any WSTEST remnant at script start = dirty session,
   hard abort (protects the sweep's exclusivity assumption)
4. Cleanup now **restores the start state** (focus + cursor back to the
   workspace/monitor recorded at B1) instead of parking on ws2

**BASELINE_BOOT3 is demoted to a failed-baseline record.** Final baseline =
next fresh-boot run with this hardened script.

## 3. Waybar highlights (new coverage)

Event-stream replay of waybar's exact algorithm (188 events captured, unit
tests green): **zero double-highlights in the scripted path** —
`m_activeWorkspaceId` always converged to the final activeworkspace
(incl. `A=10` while aws=10 during the wrap defect). Interpretation: the
double-highlight the user observes live requires `focusedmonv2` as the *last*
state-setting event — the manual mouse-interaction pattern, not the scripted
dispatch path. The invariant check stays: post-fix, `A == focused ws` must
hold universally. CSS note: `#workspaces button.focused` is dead code in
waybar 0.15 (no such class exists; only `.active` highlights).

## 4. Implementation proposal (locked in EXPECTED.md §5b)

Add two **global** functions to `hyprland.lua` (global = IPC-testable via
`hyprctl eval`, exercising the exact bind code path):

```lua
function goto_workspace(n)   -- S2 + S5: switch + cursor warp
  local ws  = hl.get_workspace(n)
  local mon = ws and ws.monitor
  if mon and hl.get_monitor_at_cursor().name ~= mon.name then
    hl.dispatch(hl.dsp.cursor.move({
      x = mon.x + mon.width / 2, y = mon.y + mon.height / 2 }))
  end
  hl.dispatch(hl.dsp.focus({ workspace = n }))
end

function cycle_workspace(delta)  -- S4: global arithmetic, wrap 9↔1
  goto_workspace(((hl.get_active_workspace().id - 1 + delta) % 9) + 1)
end
```

Rebinds:
- number binds: `for i = 1, 9` → `goto_workspace(i)`; **key-0/ws10 bind dropped** (S3)
- cycle binds `ALT/mainMod + I/U`, `mainMod+scroll` → `cycle_workspace(±1)` (S4)
- plain `focus` dispatcher **untouched** (waybar-click path unchanged — its
  semantics stay documented by phase F)
- startup workspace-creation loop kept (harmless, guarantees existence)

## 5. Validation protocol (after implementation)

1. `home-manager switch`, reboot
2. Run `tests/hypr-workspaces/ws_test.sh` once (fresh boot, hands-off)
   → **all C/T1/T2/T3 must PASS** (incl. waybar single-highlight invariant,
   `max-ws ≤ 9`)
3. Second reboot cycle → repeat → PASS again
4. Manual checklist M1–M5: real keypresses on the wrap table, alt+N from both
   cursor positions, alt+T placement, mouse-move-during-switch (waybar eyes),
   ws10 absence after 9→+1

## 6. Rollout

Implementation target branch: **`fix/dwm-workspace-cycling`** (off `main`).
The suite (this directory) is the acceptance gate; the fix branch merges only
after two clean reboot cycles per §5.
