# Baseline Analysis & Implementation Proposal — Workspace Switching

**Run:** `results/BASELINE_BOOT1` (fresh boot 2026-02-05, run once, hands-off)
> **SUPERSEDED — official baseline is now `results/BASELINE_BOOT2`** (fresh boot,
> corrected script: spawn-path fix + overlay-aware win-check + B1 label).
> Same failure map, cleaner numbers: **PASS=27 FAIL=25 SKIP=0, 25/25 genuine**
> (BOOT1's extra 2 FAILs were runner artifacts: F6 spawn-in-subshell,
> T2_HDMI-2_2 scratchpad overlay — both eliminated). Every finding below
> reproduces unchanged in BOOT2; per-case verdicts see `results/BASELINE_BOOT2/report.md`.
**Result:** **PASS=24 FAIL=28 SKIP=0** (52 checks; 1 of the 28 FAILs is a
runner-overlay artifact → **27 genuine failures**)
**Config under test:** `nixos/home-manager/config/hypr/hyprland.lua` @ current `main`
**Companion spec:** `README.md` (S1–S7) · raw report: `results/BASELINE_BOOT1/report.md`

## 1. Boot state (B1)

- Cursor −960,540 on eDP-1, focused=eDP-1, active ws=1, occupied: ws1 (runner terminal)
- **ws10 existed at boot** (workspace ids `[1..9, 10]`, ws10 empty): Hyprland
  restored the previous session's leftover — the ws10 leak is **sticky across
  reboots**. S1 violation persists until ws10 stops being created.

## 2. Failure map — all 27 genuine FAILs reduce to 3 measured defects

### Defect A — cross-monitor focus theft (empty target, cursor elsewhere)
Empty target ws → focus cleared → `follow_mouse=1` re-grabs a window under the
cursor on the *other* monitor; `no_warps=true` keeps the cursor parked.

| Phase | Failing cases | Evidence |
|---|---|---|
| F | F1, F2 (eDP→empty HDMI), F4 (HDMI→empty eDP, mirrored), F6 | switch "doesn't happen": activews stays on cursor's monitor |
| C | C2 (8→9), C5 (1→2), C6 | same |
| T1 | I1 (1→2), U1 (−1 from 1†), I8, U8 (8↔9 boundary) | same |
| T2 | eDP_2..8 (7×), HDMI_1†, HDMI_9 | **every** cross-monitor alt+N with cursor on other monitor fails; **every** same-monitor one passes (eDP_1, eDP_9, HDMI_3..8 pass) |
| T3 | T3a, T3b | alt+T kitty landed on ws9 (stolen focus ws), not target 7/8 |

† = same-defect family: HDMI_1 fails *only* on cursor (switch worked — ws1
non-empty); T1U2 same (2→1 works, cursor not warped).

### Defect B — no wraparound (unbounded arithmetic)
C3 & T1I9: `9 + 1` → **creates ws10** (max-ws≤9 invariant FAIL; becomes
boot-restored next session, see §1). C4 & T1U1: `1 − 1` → no-op.

### Defect C — cursor never warps to target monitor
Every successful cross-monitor switch leaves the cursor behind
(T1U2, T2_HDMI_1 cursor-only FAILs; also embedded in all Defect-A rows).

**Runner artifact (not a defect):** T2_HDMI-2_2 FAILs only on
`active-win='tmux'` — the runner's own scratchpad overlay reports as active
window on the focused ws. Known limitation of running the suite from inside
the session; documented here, evaluated again post-fix.

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
