# PipeWire / Bluetooth Audio Fixes for Call Latency

## Problem

During browser-based calls (Teams, Signal via `ringrtc`), audio from the local mic reached other participants with a **constant 1-3 second delay**. The delay persisted throughout the entire call — only dropping and re-joining the call would fix it.

Primary setup: **soundcore Q20i_new** Bluetooth headset connected via PipeWire/WirePlumber.

## Root Cause

PipeWire/WirePlumber suspends idle audio nodes after a timeout. When a call app (WebRTC) activates the mic, the suspended node must resume — which involves device re-initialization. If this resume is slow or incomplete, the audio pipeline enters a degraded/buffered state that persists until the stream is torn down (re-joining the call).

## Fixes Applied

All changes are in `nixos-modules/hardware/audio.nix` under `services.pipewire.wireplumber.extraConfig`.

---

### Fix 1: Disable ALSA Node Suspend

**Key:** `10-disable-suspend`

**Why:** ALSA input/output nodes (built-in sound card) get suspended after inactivity. Resuming them adds latency. This prevents that for all ALSA nodes.

**Change:**
```nix
"10-disable-suspend" = {
  "monitor.alsa.rules" = [{
      matches = [
        { "node.name" = "~alsa_input.*"; }
        { "node.name" = "~alsa_output.*"; }
      ];
      actions = {
        update-props = {
          "session.suspend-timeout-seconds" = 0;  # 0 = never suspend
        };
      };
    }
  ];
};
```

**Trade-off:** ALSA hardware stays powered on. Negligible on desktop/laptop.

---

### Fix 2: Disable Bluetooth Node Suspend + Minimize Processing

**Key:** `10-bluetooth-nosuspend`

**Why:** Same suspend issue as ALSA, but for Bluetooth (BlueZ) nodes. Also disables dithering to skip unnecessary DSP processing on the BT audio stream — reduces latency slightly.

**Change:**
```nix
"10-bluetooth-nosuspend" = {
  "monitor.bluez.rules" = [{
      matches = [
        { "node.name" = "~bluez_output.*"; }
        { "node.name" = "~bluez_input.*"; }
      ];
      actions = {
        update-props = {
          "session.suspend-timeout-seconds" = 0;
          "dither.method" = "none";
        };
      };
    }
  ];
};
```

**Trade-off:** BT audio hardware stays active. Slightly higher power consumption.

---

### Fix 3: Prefer High-Quality Bluetooth Codecs

**Key:** `11-bluetooth-codecs`

**Why:** Forces mSBC (Wideband Speech) and SBC-XQ codec negotiation instead of falling back to lower-quality defaults. mSBC provides clearer voice during calls; SBC-XQ provides better audio quality for music/listening.

**Change:**
```nix
"11-bluetooth-codecs" = {
  "monitor.bluez.properties" = {
    "bluez5.enable-msbc" = true;
    "bluez5.enable-sbc-xq" = true;
  };
};
```

**Trade-off:** None meaningful. Headset must support these codecs (soundcore Q20i does).

---

## What We Explicitly Did NOT Add

The following was considered but **skipped** to avoid over-constraining the setup:

```nix
# NOT applied — defaults are already correct
"wireplumber.settings" = {
  "bluez5.autoswitch-profile" = true;       # already the WirePlumber default
};
"monitor.bluez.properties" = {
  "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" "a2dp_sink"];
  # hardcoding roles can break if upstream defaults change
};
```

## Next Steps If Issues Persist

If the delay is still present after all three fixes:

1. **Check profile during active call:** `wpctl status` — verify headset is in HFP mode, not stuck in A2DP
2. **Tune PipeWire quantum/period:** Adjust buffer sizes in `services.pipewire.config` for lower latency
3. **Check codec in use:** `pw-cli dump short | grep bluez` — confirm mSBC is negotiated

---

## 2026-08-26: R3 mid-call poisons the autoswitch restore (fixed)

### Incident

Running R3 (profile cycle `off → headset-head-unit`) **while a call's capture
stream is open** makes WirePlumber's Bluetooth autoswitch fire during the
`off` phase. It records `off` as the profile to restore when the call ends and
pins `default-profile` to `headset-head-unit`
(`~/.local/state/wireplumber/`).

**Symptom after the call:** the card sits at `Active Profile: off` — no
`bluez_output` sink exists, playback silently falls back to the laptop
speakers, and the waybar Bluetooth widget shows its normal blue "music" state
(it only ever checked for HFP). The headset may even drop the connection while
the profile flip-flops.

### Fixes (all in `home-manager`)

1. **`scripts/rofi_call_prep.sh` — `cycle_to_headset()`**: disables
   `bluetooth.autoswitch-to-headset-profile` around every `off → HFP` cycle
   and restores the previous value afterwards. Used by prep, the F9 toggle
   (call direction) and R3.
2. **Cycle is now the standard for entering call mode** — in-place
   `A2DP → HFP` switches are the identified trigger of the 1-3s mic delay, so
   prep/toggle now perform the full `off → HFP` cycle up front. No manual R3
   should be necessary anymore; R3 remains as mid-call recovery.
3. **Action log**: entries gained `mode=` (cycle / cycle-fb / inplace) and
   `def_sink=` (bt / alsa / hdmi) fields for post-mortems.
4. **GATHER diagnostics**: now also captures the HFP *driver* node (resolved
   via `node.driver-id` of the loopback source), a `pw-dump` node runtime-state
   table (id / name / state / latency / driver per node), and 30 min of
   bluetooth/audio-relevant user journal.
5. **Waybar widget** (`config/waybar/bluetooth.sh` + `style.css`): new
   `btoff` class — orange with "⚠ audio off" tooltip when a BT card is
   connected but its profile is `off`, so a dead card can no longer masquerade
   as "music".

### Manual recovery (if it ever happens again)

```bash
pactl set-card-profile bluez_card.<MAC> a2dp-sink   # restores sink + rewrites default-profile
systemctl --user restart wireplumber                 # if the profile flip-flops back to off
```

(`wpctl set-profile <id> <name>` silently no-ops on profile *names* — it wants
the integer index; `pactl` is the reliable path.)

---

## 2026-08-31: Transport collapse loop — headset battery (resolved, no code)

### Incident

Mid-call, playback started flapping between the headset and the laptop
speakers (visible as pulsemixer flicker). The journal — newly added to GATHER
that same morning — caught it live:

```
spa.bluez5: Failure in Bluetooth audio transport .../fd41   ← every ~14 s
pw.node: (bluez_input/output...) running -> error            ← both BT nodes die
```

WirePlumber recreated the transport + sink + source every cycle (churning
object serials), the call survived on that auto-recovery. 31 transport
failures in total, 11:24–11:40, during the first call.

### Root cause: headset battery

- `bluetoothctl info` showed **20%** during the incident; the headset was
  **empty** ~2 h later. The last failure (13:49) was the A2DP transport
  terminating = battery death / power-off.
- **Zero** transport failures on any previous day — despite the same
  mSBC + off→HFP-cycle pattern on 08-26…08-28. mSBC is therefore *not*
  chronically broken on this headset.
- A full reconnect of the headset (~11:41) restored a stable link; the
  following 63-minute call had **zero** failures.

### Lessons / actions

- **H4** added to the GATHER hypotheses: transport-level collapse is a
  *battery/link* problem — R1/R2/R3 are the wrong layer. Manual levers:
  charge the headset, reconnect the device.
- Waybar widget already displays the headset battery % — glance at it before
  calls.
- If a transport loop ever recurs at *high* battery, test the CVSD profile
  (`headset-head-unit-cvsd`) as an mSBC-instability probe.
- No script changes needed; the 08-26 autoswitch guard held up through five
  cycle toggles this day (state files clean, `default-profile` = a2dp-sink).

---

## 2026-09-22: Dead transport, nodes still visible (recovered, no code)

### Incident

Playback visible in pulsemixer / browser, **but no sound**. Unlike 08-31 the
sink did NOT flap — it sat there looking healthy. Journal:

```
pw.node: (bluez_output.84_9D_4B_75_74_77.1-63) running -> error
spa.bluez5: Failure in Bluetooth audio transport .../fd42
```

Same failure class as 08-31 (`running -> error` on both BT nodes, transport
death) but a *single* collapse, not a loop — the sink/card stayed up while the
transport underneath was dead. Classic "connected but silent" presentation.

### Context: this adapter is chronically flaky

- 09-15: `Missing completion reports for packet ... Bluetooth adapter
  firmware bug?` (repeated)
- 09-16: transport `fd0` died (`terminated unexpectedly`), never recovered
  until manual intervention days later
- 09-19: device connected via **BLE only** (`Q20i_BLE`), no bluez card at all
  in PipeWire — fixed by `bluetoothctl power off/on`
- 09-22: this incident (`fd42`)

Pattern points at the adapter/link layer (firmware), not the headset stack
config. Battery remains the other known trigger (see 08-31, H4).

### Recovery recipe (in escalation order)

```bash
# 1. Force a fresh transport (works for the "connected but silent" state)
bluetoothctl power off && sleep 3 && bluetoothctl power on
bluetoothctl connect 84:9D:4B:75:74:77

# 2. If the card ends up profile 'off' or the cycle drops the device:
pactl set-card-profile bluez_card.84_9D_4B_75_74_77 a2dp-sink
#    (reconnect first if it dropped: bluetoothctl connect 84:9D:4B:75:74:77)

# 3. Escalation if the adapter is wedged (le-connection-abort-by-local etc.)
sudo systemctl restart bluetooth
```

**Verify** audio actually flows (state must be `RUNNING`, not just nodes
existing):

```bash
paplay /tmp/tone.wav &            # any wav; generate: python3 + wave module
pactl list short sinks | grep bluez   # last field: RUNNING during playback
journalctl --user -u wireplumber --since "-1 min" | grep -iE "error|fail"
```

Also check the boring causes before blaming the transport: `pactl
get-sink-mute` / `get-sink-volume` on the bluez sink, and the headset's own
hardware volume buttons (independent of system volume).

### Gotchas hit during recovery

- `pactl set-card-profile <card> off` can **drop the connection entirely**
  when the transport is already dead — don't be surprised if the device
  disappears and needs a reconnect + adapter power cycle afterwards.
- `bluetoothctl connect` right after a disconnect often fails with
  `br-connection-busy` (auto-reconnect already in progress) or
  `le-connection-abort-by-local` (adapter half-state) — power cycle the
  adapter, wait, retry.

### If it keeps recurring

- `sudo systemctl restart bluetooth` as the heavier reset
- Longer term: newer Bluetooth adapter firmware (`/lib/firmware/intel`
  firmware files) — the repeated "completion reports" warnings indict the
  adapter itself
- Check headset battery first anyway (08-31): transport collapses at low
  battery are the known alternative explanation

## 2026-09-28: Collapse at FULL battery + R3 backfired → AUTO & R4 ladder added

### Incident (reboot required)

11:00:02 the A2DP transport failed **while still in music mode, before any
user action**. F9 toggle into call mode at 11:00:04, then a full collapse
loop 11:01:48–11:03:45 (HFP `fd0` AND A2DP `fd52` transports dying every
10–30 s). R3 at 11:01:51 completed its off→HFP cycle but **`settle=n/a` — the
sink never stabilized → total silence**. Reboot at 11:03:47. A fresh single
transport failure followed at 11:17:02 in the new boot — **at 100 % battery**.

### Verdicts

- **Battery exonerated for this one**: headset fully charged that morning;
  the 11:17 failure happened at 100 %.
- **Kernel-update regression ruled out**: transport failures span three
  system generations (pre-Sep-10, gen 566 = 6.18.38, gen 569 = 6.18.53).
- Remaining suspects: the **chronically flaky internal adapter** (see
  2026-09-22 section for the 09-15…09-22 history) and mSBC (CVSD probe
  still pending — indicated now that battery is ruled out).
- **R3 mid-collapse is actively harmful**: the `off` phase removes the last
  working sink; on a dying link the fresh transport never stabilizes →
  silence instead of flapping audio. R1–R3 are PipeWire-layer tools; this
  failure lives in the link layer (H4).

### Code: AUTO triage + R4 ladder (rofi_call_prep.sh)

The R1–R3 menu had no lever for link-layer failures and gave no visibility
into WHICH failure mode was live. Added:

- **AUTO** — read-only triage (~2 s), notifies the verdict, then runs the
  matching fix: pactl timeout → R4c · no card → R4a · ≥2 transport failures
  in 3 min → R4a · streams off the BT sink → R2 · streams active + stable
  link → R3 · nothing wrong → no-op. R3 is only chosen when the link is
  provably stable.
- **R4a** — PC-side headset reconnect (`bluetoothctl disconnect/connect`, NO
  headset buttons, call survives, ~10–15 s gap) + guarded HFP bring-up +
  stream re-pinning. Proven 2026-09-09.
- **R4b** — adapter power cycle (`bluetoothctl power off/on`) — codifies the
  09-22 recovery recipe step 1; escalation when R4a doesn't bring the card.
- **R4c** — `systemctl --user restart wireplumber pipewire pipewire-pulse` +
  R4a — the proven 2026-09-09 wedged-stack recovery.
- AUTO escalates R4a → R4b automatically; all actions log
  `mode=r4a/r4b/r4c/auto-<MODE>` to call-prep.log.

### New mid-call playbook

Audio breaks during a call → run **AUTO** (rofi or `rofi_call_prep.sh auto`).
Read the verdict notification, let it fix the right layer. Manual R4 if you
already know it's the link. R3 only when AUTO reports `STALE-LOOPBACK?`

## 2026-10-15: Collapse raced past AUTO — triage hardened + escalation added

### Incident

Link sick BEFORE the call (09:59:47 A2DP transport death while idle — third
incident with the "long-idle connection dies on first activity" pattern;
battery 70 %). Full collapse 10:01:40–10:02:54 (~10 transport deaths / 75 s)
during the Teams call. User pressed AUTO at ~10:01:41 — the decisive 10:01:40
failure **was not yet flushed to the journal** → triage counted 1 instead of
2 → false `STALE-LOOPBACK?` → R3 cycled onto the dying link → no effect.
Manual **R4a + call restart fixed it** (first real-world R4a success).

### Fixes (rofi_call_prep.sh)

- **Triage hardening** — three collapse signals, any one fires:
  (a) ≥2 transport failures / 5 min · (b) ≥4 bluez node-error lines / 5 min ·
  (c) ANY transport failure in the last 2 min WHILE a call capture is active
  (race-proof: even with total journal lag on the newest event, earlier
  deaths are in the window; verified by journal replay of the exact morning).
- **AUTO verify & escalate**: after R3, 3 s re-check — new or ongoing (≥2)
  failures → auto-escalate R4a → R4b with a notification. A misclassified R3
  now self-corrects within seconds.
- **R3 settle instrumentation**: sink-wait ≤5 s, logged as `settle=`.

### Follow-up (same day): verified call-mode entry (F9 / prep)

User request: do a pre-emptive R4a when switching to call mode. Implemented
as **conditional + verify** (best of both worlds — fast when healthy,
protective when sick, covers the first call of the day on an empty journal):

- any transport failure in the last 2h → straight to R4a reconnect (~10s,
  measured), then call-ready
- otherwise fast off→HFP cycle + 3s verify: fresh transport died or no sink
  → automatic R4a BEFORE joining
- healthy-path cost: ~5s (was ~3s). Live-tested 10:57 (2h look-back caught
  the 10:12 failure): R4 + `mode=r4a-prep` logged, call-ready in 9.8s.

### Open threads

- Chronic link degradation continues (Sep 15 → Oct 15). CVSD probe and/or a
  USB BT dongle remain the recommended next steps.

### Follow-up 2 (same day): the reconnect profile race — R4a hardened

**Incident:** after deploying the verified F9, both F9 presses took the
sick-path (R4a). First one (11:27:02) silently ended in **a2dp** — R4's own
log said `post=hhu` while the toggle line, same second, saw a2dp (waybar
"no audio"). User rescued by a direct off→hhu cycle. Both F9s were also
justified: the link died at 11:26:52 *again* (5th collapse cluster of the
day: 10:01, 10:12, 11:26, 11:30, 11:36 — worst day yet, battery 70 %).

**Root cause (instrumented, 0.25s profile polling):** an async actor applies
**a2dp ~2.3 s after every card reconnect** (A2DP endpoint registration
window), firing even with `autoswitch-to-headset-profile` disabled and
regardless of the saved default (which says hhu). It is single-shot per
reconnect. Identity inside WirePlumber unknown (not autoswitch policy, not
default-profile, not bluetooth-autoswitch state) — behavior is fully
characterized and defended against; a debug-logging WP restart would reveal
the component if ever needed.

**Fixes in r4_bringup/do_r4a:**
1. **Pre-arm**: set HFP *before* disconnecting → WirePlumber saves hhu as
   default → its post-reconnect restore lands on hhu (verified: card comes
   back as hhu).
2. **Watch & re-assert window**: 5×1s watch with NO early break (a
   break-on-hhu loop exits before the actor's window opens — the subtle
   second bug), re-applying HFP whenever the flip lands. R4a now ~15 s.
3. **Final gate + honest rc**: success requires profile=hhu AND sink (a2dp
   also has a sink — the old rc passed in a2dp!). enter_call_verified
   likewise checks the *profile*, not just sink presence.

Proven live: actor flip caught mid-window, hhu stable ≥25 s after.

## 2026-10-19: "connected but off" zombie state → bt-audio-guard watcher

**Incident:** after a rescued call, WirePlumber's post-call switch back to
A2DP hit a dying transport (12:18:46, fd52) and parked the card at profile
`off` — connected headset, zero sinks, waybar yellow "⚠ audio off", no
audio until manual recovery. A connected headset without a sink is useless.

**Fix: `bt_audio_guard.sh`** (systemd user service `bt-audio-guard`,
deployed via scripts.nix):

- polls every 10 s; if BT card = `off` while the headset is connected for
  ≥ 30 s (debounce covers all transient off-states of R3/R4a cycles, whose
  disconnect windows have *no card* instead of off), and no call-prep
  action is running → runs `rofi_call_prep.sh music`, notifies, logs as
  `guard` entries in call-prep.log
- 90 s cooldown between attempts; retries naturally if the link is dead
- recovery itself is the hardened music path; waybar warning doubles as
  the visibility indicator (should self-clear yellow→green in ~40 s)

Also this day: audio stack hang at call start (10:59, pactl timeouts) —
cured with the Sep 9 recipe (user-unit restart + reconnect); F9 itself had
succeeded (`mode=cycle-verify` logged).

### Follow-up (same day): guard worked; widget needed PipeWire eyes

First live fire of `bt-audio-guard`: watcher started 12:27:06, detected
`connected+off` after the 30s debounce 12:27:46, recovered to music
(`mode=inplace post=a2dp-sink`) — audio back, sink = 2ch A2DP. Exactly as
designed, zero interaction.

Residual: waybar still warned "⚠ audio off" — the widget's leader only
listened to **BlueZ** D-Bus signals, but profile changes are **PipeWire**
events with no BlueZ counterpart. Fix: the leader's coproc now merges TWO
sources — dbus-monitor (BlueZ) + `LC_ALL=C pactl subscribe | grep
--line-buffered -- 'on card'` (respawn-loop, 5 s retry after a stack
restart). The LC_ALL=C matters: German locale prints "auf Karte" and a
plain `grep 'on card'` never matches (re-discovered the hard way).
Validated: two pactl profile flips → four card events delivered.
