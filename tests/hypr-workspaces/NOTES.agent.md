# AGENT NOTES — local, not for commit

## PROTOCOL (user-mandated, 2026-02-10)

**NO `git push` (and no local commits) until the baseline is CLEAN and
EXPLICITLY ACCEPTED by the user.**

After the next fresh-boot run (BOOT4):
1. Run `ws_test.sh` once, hands-off, follow notify-send progress
2. Verify: 52 checks executed (T3b must actually RUN, not SKIP), zero WSTEST
   remnants (windows AND processes), start state restored (focus+cursor back
   to the ws recorded at B1)
3. Report results to the user and **STOP — wait for explicit acceptance**
4. Only after acceptance: commit + push the baseline, then proceed to
   implementation on `fix/dwm-workspace-cycling` (ANALYSIS-baseline.md §4)

## State right now

- Script REDESIGNED (uncommitted, per user): PROCESS OWNERSHIP model —
  setsid kitty & → $! = pgid; close = ONE `kill -- -pgid` (window + kittens,
  no compositor dispatch, no window.kill, no address bookkeeping).
  wstest_procs: comm-based (.kitty-wrapped Nix wrapper), zombie-immune,
  self-match-immune; pgid_alive: zombie-immune. Validated live: group semantics (two groups, per-group death), idempotent
  re-close logs "already closed", false-ERROR attribution removed (per-group
  verify only; global zero-remnant assert ONLY in final cleanup).

FIX BRANCH fix/dwm-workspace-cycling @987cd95: goto_workspace/cycle_workspace implemented
  (globals + rebinds 1..9, key-0 dropped). BOOT8: suite-driver bug (eval
  rejects unary +) -> fixed @post-987cd95; T2 18/18 PASS, T3a/T3b PASS,
  T1U*/C4 PASS (wrap works). BOOT9 (next fresh boot) expected: C/T1/T2/T3
  all PASS; F1/F2/F4 stay FAIL by design (plain focus untouched); B1a until
  a boot restores a session without ws10.
  26/26/0, T3b ran, zero remnants, restored ws1) but had 4 false [KILL][ERROR]
  log lines -> user rejected fixing-after-acceptance; fixed BEFORE baseline.
  (exist/live/dead×2). Validated: TERM alone suffices, no kill -9 needed.
  start-state restore, spawn POLL, and spawn-success = LIVE WINDOW lookup
  (BOOT4+BOOT5 T3b bug: compositor recycles addresses — a killed address was
  reused for the next spawn and my KILLED[addr] bookkeeping marked the new
  live window dead; liveness now read from wstest_windows directly).
  start-state restore, spawn POLL (was fixed 2.5s sleep — BOOT4: T3b window
  mapped late, skip; events.log 628 vs fixed poll).
  start-state restore). BOOT3 demoted (T3b SKIP + leftover + no restore).
- Expected BOOT4 defect map (= all prior runs): B1a ws10-at-boot FAIL,
  A theft: F1/F2/F4 + C2–C6 + T1{I1,U1,U2,I8,U9,I9} + T2 eDP_2..8 &
  HDMI_1/HDMI_9 + T3a/T3b, B wrap: C3/T1I9 create ws10, C4/T1U1 no-op.
  Expected ≈ 26 PASS / 26 FAIL / 0 SKIP (T3b now runs and should FAIL pre-fix).
- This file: untracked on purpose — do NOT `git add` it.

## Reset 2026-02-10 (user decision, non-negotiable)
- Script @fe8c1ad (unary-plus driver fix) is FROZEN — it is THE instrument now.
- hyprland.lua fix REVERTED @520a0e6 (987cd95 kept in history for re-application:
  `git revert 520a0e6` or `git cherry-pick 987cd95` after the new baseline).
- Protocol: fresh baseline with script@fe8c1ad on UNFIXED system (before-run),
  then re-apply fix, switch, reboot, after-run. Same instrument for both.
- Expected before-run map: BOOT7's 26-map; B1a uncertain (BOOT8 session created
  no ws10 → may restore without it → 25-map; both outcomes are valid records).

## NEW UNDETECTED DEFECT (user report, 2026-02-10)
- Switch to a workspace on a DIFFERENT screen that has an ACTIVE WINDOW:
  workspace switches, but keyboard focus STAYS on the original display's
  window (window-level focus theft — F5/F6 only assert focused MONITOR, not
  that the target window receives focus). Candidate check F7: prep cursor on
  M_a with active window w1; focus NON-EMPTY ws on M_b (window w2); assert
  activewin == w2 AND activews == target AND focused monitor == M_b.
- NOT added yet: adding it changes the benchmark — decision pending (add
  before the before-run, or note-only for the next cycle).

## BOOT9-diagnostic (run 23:47, 2026-10-09) — NOT the accepted before-run
- 27/29/0 (56 checks), modes legacy/legacy, zero remnants, start state restored
- Core map byte-identical to BOOT7 (+ B1a: ws10 again — session restore
  self-perpetuates; + F7/T4a/T4b first-ever measurements, all FAIL = user
  complaint confirmed on the bind path)
- EXPOSED INSTRUMENT FLAW: spawn_on_ws relied on the plain dispatcher for
  placement — class-A theft made F7's kitty map on ws1 (snapshot proof:
  ws1 win=2, ws4 win=0). Post-fix this would artifact false FAILs on T4a.
- FIX (this commit): spawn_on_ws = cursor_to(target monitor) FIRST, then
  focus_ws, then spawn — placement deterministic in both modes
- Extra diagnostics same evening: DIAGNOSTIC_20261009_2302 (52-check, 26P),
  DIAGNOSTIC_20261009_2324 (56-check, 34P, fix still live)
- NEXT: fresh boot (no lull needed — config unchanged, only the script moved)
  → single run = ACCEPTED BEFORE-run for the before/after comparison

## BEFORE_BOOT10 (run 23:58, 2026-10-09) — ACCEPTED before-run
- instrument @47c1811 (56 checks), fresh boot, single run, modes legacy/legacy
- 27/29/0, zero remnants, start state restored — clean run, no anomalies
- FAIL map (29) == diagnostic map: B1a F1 F2 F4 F7 C2 C3 C4 C5 C6 T1U1 T1I1
  T1U2 T1I8 T1U9 T1I9 T2_eDP-1_2..8 T2_HDMI-A-2_1 T2_HDMI-A-2_9 T3a T3b T4a T4b
  → two independent boots, identical map: reproducible baseline
- Placement fix EFFECTIVE: F7 now reaches its target state (ws=4@HDMI,
  win=WSTEST) — on legacy it fails ONLY the cursor-warp expectation;
  T4a likewise (win=WSTEST, fails only warp); T4b fails wrap (B-class).
  KEY FINDING: window-focus (class) per se HOLDS on legacy under suite
  conditions; the theft the suite measures is monitor/cursor-level (A-class)
  + missing wrap (B-class) + missing warp (C-class). F7/T4a/T4b turn fully
  green only with the fix (warp + wrap + monitor follow).
- NEXT: git revert 520a0e6 (re-apply fix) → lull → reboot → after-run

## AFTER1-diagnostic (BOOT11, run 00:07, 2026-10-10) — fix v1 insufficient
- 49/7/0, modes fixed/fixed, zero remnants. C/T1/T2/T3 all green (wrap +
  warp + monitor-follow fixed), F8/T4b PASS.
- REMAINING RED: B1a (session-restore ws10, decays), F1/F2/F4 (plain
  dispatcher — by design), F7 (instrument: cursor-warp expectation on the
  plain-dispatcher path — unfixable by design, same verdict both sides),
  C6 (expectation ambiguity: cycle computed from FOCUSED monitor's ws —
  defensible dwm semantics; document, don't chase), and T4a — THE REAL ONE:
- T4a: goto_workspace(7) cross-monitor: ws ✓ mon ✓ cursor-warp ✓ but
  keyboard focus STAYED on the scratchpad (active-win class KittyScratchpad).
  ROOT CAUSE (verified in v0.56.2 source): hl.dsp.focus({workspace=N}) maps
  to CA::changeWorkspace — ws/monitor switch only, NO window focus.
- FIX v2 (this commit): after changeWorkspace, pick the target ws's
  most-recently-focused window via hl.get_windows() + focus_history_id
  (>= 0 filter), then hl.dsp.focus({window = "address:0x…"}).
  Verified live: selector-focus works, pick-loop returns sane candidates.
- T4b/F8 PASSes may have been measuring "WSTEST never lost focus" (spawn
  held it; focus(ws1) doesn't steal) — fix v2 makes them true positives.
- Instrument stays @47c1811. NEXT: lull -> reboot -> AFTER2 run.

## AFTER_BOOT12 (00:20, 2026-10-10) — ACCEPTED after-run (fix v2)
- 50/6/0, modes fixed/fixed, zero remnants, start state restored
- Delta vs BEFORE_BOOT10: 23 red->green, 0 green->red (strict improvement)
- Remaining 6 reds, all pre-existing in before-run: B1a (ws10 residue),
  F1/F2/F4 (plain dispatcher, by design), F7 (instrument: warp expectation
  on dispatcher path; class assertion passes), C6 (dwm-semantics ambiguity)
- T4a/T4b/F8/F7-class: PASS — keyboard focus follows to the target ws's app
- Protocol per ANALYSIS §5: needs a SECOND clean cycle (reboot + rerun,
  config unchanged — no lull) + manual checklist M1–M5, then merge.

## AFTER2_BOOT13 (00:31, 2026-10-10) — second clean cycle: REPRODUCED
- 50/6/0, modes fixed/fixed, zero remnants; PASS+FAIL maps byte-identical
  to AFTER_BOOT12 (diff-verified). §5 automation requirement satisfied.
- REMAINING: manual checklist M1–M5, then merge to main.

## S6 (2026-10-10, post-soak) — pointer-coherent monitor/history paths
- Live repro (user): alt+, with pointer hovering a browser link on the source
  monitor -> waybar flips to ws1 then immediately back to ws2; keyboard
  focus/blue border stays ws1; new terminals spawn on ws2 (split brain).
- Root cause (v0.56.2 source-verified): focus({monitor="+1"}) warps via
  warpCursor() -> PointerController::warpTo, which under cursor:no_warps=true
  (config line 111) flips monitor focus but leaves the pointer behind;
  input:follow_mouse=1 (line 85) then re-asserts the window under the pointer
  on any mouse activity (mouseMoveUnified refocus, delta > threshold).
  alt+N immune: goto_workspace pre-warps via dsp.cursor.move (force=true).
- FIXES (local, NOT pushed; tag ws-fix-v2-validated marks the soak-good state):
  - goto_monitor(d): goto target monitor's ACTIVE ws (its own state decides)
  - goto_previous_workspace(): hl.get_last_workspace() (Hyprland's own
    history tracker, same source as "previous"); no warp on same-display
    history; guard: prev==current -> no-op (old behavior preserved)
  - move_window_to_monitor(d): send-and-follow — pre-warp cursor to target
    center, then window.move({monitor=target, follow=true}) (its warpCursor
    would be neutered by no_warps -> pre-warp required)
  - binds: ALT+comma, ALT+SHIFT+comma, mainMod+Escape, ALT+Escape
- All API primitives live-probed: get_last_workspace -> HL.Workspace(1:1);
  monitor math CUR=HDMI-A-2 -> TARGET=eDP-1 ws1; get_active_window verified.
- User tests manually before push; rollback = checkout ws-fix-v2-validated.
