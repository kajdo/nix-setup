# Local diagnostics captures (persistent, machine-local, untracked)

This directory is deliberately excluded from git (see root `.gitignore`).
It lives inside the repo anyway so captures survive `/tmp` cleanups and reboots.

## Contents

- `gpu-error-<timestamp>.txt` — i915 GPU error-state dumps, auto-captured by the
  `gpu-error-capture` systemd service/timer whenever a new GPU hang is detected
  (see `nixos/nixos-modules/services/gpu-error-capture.nix`).
- `gpu-context-<timestamp>.log` — kernel log (`journalctl -k`) around the
  corresponding hang, for correlation.
- `gpu-error-manual-*.txt` — one-off manual captures, e.g.
  `sudo cat /sys/class/drm/card0/error > logs/gpu-error-manual-$(date +%Y%m%d-%H%M%S).txt`

## Known incidents

- 2026-08-16 16:28:57 — i915 `GPU HANG: ecode 8:0:00000000`, engine reset `rcs0`
  (~20 s full-system stall while opening kitty with YouTube playing; recovered
  cleanly, no further DRM errors after the reset).
