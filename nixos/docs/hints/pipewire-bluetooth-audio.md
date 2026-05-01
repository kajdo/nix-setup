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
