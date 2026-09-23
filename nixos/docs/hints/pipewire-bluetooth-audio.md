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
